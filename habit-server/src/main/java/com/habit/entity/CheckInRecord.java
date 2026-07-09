package com.habit.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("check_in_record")
public class CheckInRecord {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long habitId;
    private Long userId;
    private String checkInDate;
    private String remark;
    private String imageUrl;

    /** 是否最终完成（一次性打卡用） */
    private Integer isFinal;

    private LocalDateTime checkInTime;

    @TableField(exist = false)
    private String fullImageUrl;

    // 习惯名称
    @TableField(exist = false)
    private String habitName;

    // 习惯图标
    @TableField(exist = false)
    private String habitIcon;
}
