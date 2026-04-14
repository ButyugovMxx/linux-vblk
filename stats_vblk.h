#include <linux/types.h>


struct stats{
    u64 reads;
    u64 writes;
    u64 errors;
    u64 read_sectors;
    u64 write_sectors;
};


void vblk_stats_init(struct stats *vblk_stats);
void vblk_stats_read(struct stats *vblk_stats, u64 sectors);
void vblk_stats_write(struct stats *vblk_stats, u64 sectors);
void vblk_stats_error(struct stats *vblk_stats);

