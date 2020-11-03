#!/bin/bash


cluster=$HOSTNAME
mount_point=/nirmata-backup
backup_dir=$mount_point/$cluster
nadm=~/bin/nadm
namespace=nirmata


mkdir -p $mount_point
umount -l -f  $mount_point
mount $mount_point

mkdir -p $backup_dir

$nadm backup --all -d $backup_dir -n $namespace
