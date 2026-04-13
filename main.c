#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/blkdev.h>
#include "stats_vblk.h"

struct vblk_dev{
    int major;
    struct gendisk *disk;
    struct file *back_file;
    struct block_device *back_disk;
    sector_t capacity;
    struct bio_set bio_pool;
    struct stats vblk_stats;
};

static void vblk_submit_bio(struct bio *bio);
static void vblk_end_io(struct bio* clone);

static const struct block_device_operations fops = {
	.owner = THIS_MODULE,
    .submit_bio = vblk_submit_bio,
};

static struct vblk_dev vblk = {
	.major = 0,
};

static int vblk_open_backend(const char * path){
	blk_mode_t mode;
	int err;
	mode = BLK_OPEN_READ | BLK_OPEN_WRITE;

	vblk.back_file = bdev_file_open_by_path(path, mode, &vblk, NULL);
	if(IS_ERR(vblk.back_file)){
		err = PTR_ERR(vblk.back_file);
		vblk.back_file = NULL;
		pr_err("failed to open backend: %d\n", err);
		return err;
	}

	vblk.back_disk = file_bdev(vblk.back_file);

	return 0;
}	

static void vblk_close_backend(void){
	if(vblk.back_file){
		bdev_fput(vblk.back_file);
		vblk.back_file = NULL;
		vblk.back_disk = NULL;
	} 
}

static void vblk_submit_bio(struct bio *bio){
    struct bio *clone;
    uint64_t sectors;

    sectors = bio_sectors(bio);

    if(bio_op(bio) == REQ_OP_READ) vblk_stats_read(&vblk.vblk_stats, sectors);
    if(bio_op(bio) == REQ_OP_WRITE) vblk_stats_write(&vblk.vblk_stats, sectors);

    clone = bio_alloc_clone(vblk.back_disk, bio, GFP_NOIO, &vblk.bio_pool);
    if(!clone){
        vblk_stats_error(&vblk.vblk_stats);
        bio_io_error(bio);
        return;
    }

    clone->bi_private = bio;
    clone -> bi_end_io = vblk_end_io;
    pr_info("submit_bio called\n");

    submit_bio_noacct(clone);
}

static void vblk_end_io(struct bio* clone){
    struct bio *orig = clone->bi_private;

    if(clone->bi_status){ 
        vblk_stats_error(&vblk.vblk_stats);
        bio_io_error(orig);
    }
    else{bio_endio(orig);}
    pr_info("end_io called\n");
    bio_put(clone);
}

static int __init vblk_init(void){

    vblk.major = register_blkdev(0,"vblk");
    if(vblk.major < 0){
        pr_err("failid to register blvk: %d\n", vblk.major);
        return vblk.major;
    }
    
    int err = vblk_open_backend("/dev/loop0");
    if(err){
	unregister_blkdev(vblk.major, "vblk");
    	return err;
    }

    int size_of_sectors = get_capacity(vblk.back_disk->bd_disk);
    vblk.capacity = size_of_sectors;
    
    struct queue_limits lim = { };

    vblk.disk = blk_alloc_disk(&lim, NUMA_NO_NODE);
    if(!vblk.disk){
        unregister_blkdev(vblk.major, "vblk");
        return -ENOMEM;
    }

    vblk.disk->major = vblk.major;
    vblk.disk->first_minor = 0;
    vblk.disk->minors = 1;
    vblk.disk->fops = &fops;
    strscpy(vblk.disk->disk_name, "vblk01", DISK_NAME_LEN);

    set_capacity(vblk.disk, vblk.capacity);
    
    err = bioset_init(&vblk.bio_pool, 64, 0, BIOSET_NEED_BVECS);
    if(err){
        unregister_blkdev(vblk.major, "vblk");
        return err;
    }

    vblk_stats_init(&vblk.vblk_stats);

    err = add_disk(vblk.disk);
    if(err){
	put_disk(vblk.disk);
	vblk_close_backend();
	bioset_exit(&vblk.bio_pool);
	unregister_blkdev(vblk.major, "vblk");
	return err;
    }
    pr_info("module loaded: %d\n", vblk.major);
    return 0;
}

static void __exit vblk_exit(void){
    if(vblk.disk){
        del_gendisk(vblk.disk);
        vblk.disk = NULL;
    }
    vblk_close_backend();
    if(vblk.major) unregister_blkdev(vblk.major, "vblk");
    bioset_exit(&vblk.bio_pool);
    
    pr_info("vblk: reads=%llu writes=%llu read_sectors=%llu written_sectors=%llu errors=%llu\n",
	vblk.vblk_stats.reads,
	vblk.vblk_stats.writes,
	vblk.vblk_stats.read_sectors,
	vblk.vblk_stats.write_sectors,
	vblk.vblk_stats.errors);
    pr_info("module unloaded: %d\n", vblk.major);
}

module_init(vblk_init);
module_exit(vblk_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("ButugovMxx");
MODULE_DESCRIPTION("Virtual block device");
