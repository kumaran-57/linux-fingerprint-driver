#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdint.h>
#include <stdbool.h>

typedef enum {
    SENSOR_STATE_IDLE,
    SENSOR_STATE_ACTIVE,
    SENSOR_STATE_STREAMING,
    SENSOR_STATE_STOPPED
} mock_sensor_state_t;

typedef struct {
    uint16_t vid;
    uint16_t pid;
    uint8_t width;
    uint8_t height;
    uint16_t fw_ver;
    mock_sensor_state_t state;
    bool led_on;
} mock_elan_sensor_t;

void mock_sensor_init(mock_elan_sensor_t *dev)
{
    dev->vid = 0x04f3;
    dev->pid = 0x0903;
    dev->width = 96;
    dev->height = 96;
    dev->fw_ver = 0x0170;
    dev->state = SENSOR_STATE_IDLE;
    dev->led_on = false;
}

int mock_sensor_send_cmd(mock_elan_sensor_t *dev, const uint8_t *cmd, size_t len, uint8_t *resp, size_t *resp_len)
{
    if (len != 2) return -1;

    if (cmd[0] == 0x40 && cmd[1] == 0x31) {
        /* LED ON / Activate */
        dev->led_on = true;
        dev->state = SENSOR_STATE_ACTIVE;
        *resp_len = 0;
        return 0;
    } else if (cmd[0] == 0x00 && cmd[1] == 0x0c) {
        /* Get Sensor Dim */
        resp[0] = dev->width;
        resp[1] = 0x00;
        resp[2] = dev->height;
        resp[3] = 0x00;
        *resp_len = 4;
        return 0;
    } else if (cmd[0] == 0x40 && cmd[1] == 0x19) {
        /* Get FW Ver */
        resp[0] = (dev->fw_ver >> 8) & 0xFF;
        resp[1] = dev->fw_ver & 0xFF;
        *resp_len = 2;
        return 0;
    } else if (cmd[0] == 0x00 && cmd[1] == 0x0b) {
        /* Stop */
        dev->led_on = false;
        dev->state = SENSOR_STATE_STOPPED;
        *resp_len = 0;
        return 0;
    }

    return -2; /* Unknown command */
}

void test_mock_lifecycle(void)
{
    printf("[*] Running test_mock_lifecycle...\n");
    mock_elan_sensor_t sensor;
    mock_sensor_init(&sensor);

    assert(sensor.state == SENSOR_STATE_IDLE);
    assert(sensor.vid == 0x04f3);
    assert(sensor.pid == 0x0903);

    /* 1. Query Sensor Dim */
    uint8_t cmd_dim[2] = {0x00, 0x0c};
    uint8_t resp[64];
    size_t resp_len = 0;
    int rc = mock_sensor_send_cmd(&sensor, cmd_dim, 2, resp, &resp_len);
    assert(rc == 0);
    assert(resp_len == 4);
    assert(resp[0] == 96 && resp[2] == 96);
    printf("    PASS: Dim response verified (96x96 matrix).\n");

    /* 2. LED On */
    uint8_t cmd_led[2] = {0x40, 0x31};
    rc = mock_sensor_send_cmd(&sensor, cmd_led, 2, resp, &resp_len);
    assert(rc == 0);
    assert(sensor.led_on == true);
    assert(sensor.state == SENSOR_STATE_ACTIVE);
    printf("    PASS: Sensor transition to ACTIVE verified.\n");

    /* 3. Stop */
    uint8_t cmd_stop[2] = {0x00, 0x0b};
    rc = mock_sensor_send_cmd(&sensor, cmd_stop, 2, resp, &resp_len);
    assert(rc == 0);
    assert(sensor.led_on == false);
    assert(sensor.state == SENSOR_STATE_STOPPED);
    printf("    PASS: Sensor transition to STOPPED verified.\n");
}

int main(void)
{
    printf("=== ELAN Mock Sensor Tests ===\n");
    test_mock_lifecycle();
    printf("ALL MOCK SENSOR TESTS PASSED.\n");
    return 0;
}
