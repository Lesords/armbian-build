#!/bin/bash
# pwm_ctrl.sh
# 参数：1 开启PWM，0 关闭PWM
# 固定配置：period=1000000，duty_cycle=500000

PWM_CHIP="/sys/class/pwm/pwmchip0"
PWM_NUM=0
PERIOD=1000000
DUTY=500000

# 参数校验
if [ $# -ne 1 ]; then
    echo "usage: $0 [0|1]"
    echo "  0 : disable pwm0"
    echo "  1 : enable pwm0"
    exit 1
fi
CMD=$1

# 导出pwm通道，已导出忽略报错
echo $PWM_NUM > ${PWM_CHIP}/export 2>/dev/null

# 统一配置周期与占空比
echo $PERIOD > ${PWM_CHIP}/pwm${PWM_NUM}/period
echo $DUTY > ${PWM_CHIP}/pwm${PWM_NUM}/duty_cycle

# 开关控制
if [ "$CMD" -eq 1 ]; then
    echo 1 > ${PWM_CHIP}/pwm${PWM_NUM}/enable
    echo "pwm0 enabled, period=$PERIOD duty=$DUTY"
elif [ "$CMD" -eq 0 ]; then
    echo 0 > ${PWM_CHIP}/pwm${PWM_NUM}/enable
    echo "pwm0 disabled"
else
    echo "invalid argument, only accept 0 or 1"
    exit 1
fi

exit 0
