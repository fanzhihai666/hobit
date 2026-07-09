CREATE TABLE `user` (
                        `id` bigint NOT NULL AUTO_INCREMENT COMMENT '用户ID',
                        `username` varchar(32) NOT NULL COMMENT '账号',
                        `password` varchar(64) NOT NULL COMMENT '密码',
                        `nickname` varchar(32) DEFAULT '' COMMENT '昵称',
                        `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
                        PRIMARY KEY (`id`),
                        UNIQUE KEY `uk_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

-- 习惯表
CREATE TABLE `habit` (
                         `id` bigint NOT NULL AUTO_INCREMENT,
                         `user_id` bigint NOT NULL COMMENT '所属用户ID',
                         `name` varchar(50) NOT NULL COMMENT '习惯名称',
                         `category` varchar(20) DEFAULT '学习' COMMENT '分类：学习/运动/生活/自定义',
                         `priority` int DEFAULT 3 COMMENT '优先级 1-5',
                         `remind_time` varchar(10) DEFAULT '' COMMENT '提醒时间 HH:mm',
                         `icon` varchar(20) DEFAULT '📌' COMMENT '图标emoji',
                         `is_deleted` tinyint(1) DEFAULT 0 COMMENT '软删除 0未删 1已删',
                         `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
                         PRIMARY KEY (`id`),
                         KEY `idx_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='习惯表';

-- 打卡记录表
CREATE TABLE `check_in_record` (
                                   `id` bigint NOT NULL AUTO_INCREMENT,
                                   `habit_id` bigint NOT NULL COMMENT '习惯ID',
                                   `user_id` bigint NOT NULL COMMENT '用户ID',
                                   `check_in_date` varchar(20) NOT NULL COMMENT '打卡日期 yyyy-MM-dd',
                                   `remark` varchar(500) DEFAULT '' COMMENT '文字备注',
                                   `image_url` varchar(255) DEFAULT '' COMMENT '打卡图片地址',
                                   `check_in_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '打卡时间',
                                   PRIMARY KEY (`id`),
                                   KEY `idx_user_date` (`user_id`,`check_in_date`),
                                   KEY `idx_habit_id` (`habit_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='打卡记录表';
