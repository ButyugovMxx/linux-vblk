#include "stats_vblk.h"

void vblk_stats_init(struct stats *vblk_stats)
{
    vblk_stats->read_sectors = 0;
    vblk_stats->reads = 0;
    vblk_stats->write_sectors = 0;
    vblk_stats->writes = 0;
    vblk_stats->errors = 0;
}

void vblk_stats_read(struct stats *vblk_stats, u64 sectors)
{
    vblk_stats->reads++;
    vblk_stats->read_sectors += sectors;
}


void vblk_stats_write(struct stats *vblk_stats, u64 sectors)
{
    vblk_stats->writes++;
    vblk_stats->write_sectors += sectors;
}

void vblk_stats_error(struct stats *vblk_stats)
{
    vblk_stats->errors++;
}

