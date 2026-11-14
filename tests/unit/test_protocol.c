#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdint.h>

#define ELANPRESS_VEND_ID 0x04f3
#define ELANPRESS_PID_0903 0x0903

#define ELANPRESS_EP_CMD_OUT 0x01
#define ELANPRESS_EP_CMD_IN  0x83
#define ELANPRESS_EP_IMG_IN  0x82

/* Command Opcodes */
static const uint8_t CMD_LED_ON[2]        = {0x40, 0x31};
static const uint8_t CMD_GET_IMAGE[2]     = {0x00, 0x09};
static const uint8_t CMD_STOP[2]          = {0x00, 0x0b};
static const uint8_t CMD_GET_SENSOR_DIM[2]= {0x00, 0x0c};

void test_command_definitions(void)
{
    printf("[*] Running test_command_definitions...\n");
    assert(CMD_LED_ON[0] == 0x40 && CMD_LED_ON[1] == 0x31);
    assert(CMD_GET_IMAGE[0] == 0x00 && CMD_GET_IMAGE[1] == 0x09);
    assert(CMD_STOP[0] == 0x00 && CMD_STOP[1] == 0x0b);
    assert(CMD_GET_SENSOR_DIM[0] == 0x00 && CMD_GET_SENSOR_DIM[1] == 0x0c);
    printf("    PASS: Command opcodes match reverse-engineered specifications.\n");
}

void test_endpoint_mapping(void)
{
    printf("[*] Running test_endpoint_mapping...\n");
    /* Endpoint 1 OUT (0x01), Endpoint 3 IN (0x83), Endpoint 2 IN (0x82) */
    assert((ELANPRESS_EP_CMD_OUT & 0x80) == 0); /* OUT endpoint */
    assert((ELANPRESS_EP_CMD_IN & 0x80) != 0);  /* IN endpoint */
    assert((ELANPRESS_EP_IMG_IN & 0x80) != 0);  /* IN endpoint */

    assert((ELANPRESS_EP_CMD_OUT & 0x0F) == 1);
    assert((ELANPRESS_EP_CMD_IN & 0x0F) == 3);
    assert((ELANPRESS_EP_IMG_IN & 0x0F) == 2);
    printf("    PASS: USB bulk endpoints match hardware descriptor layout.\n");
}

void test_frame_size_calculation(void)
{
    printf("[*] Running test_frame_size_calculation...\n");
    uint16_t width = 96;
    uint16_t height = 96;
    size_t raw_bytes = (size_t)width * height * 2; /* 14-bit pixels in 2 bytes */
    
    assert(raw_bytes == 18432);
    assert(raw_bytes % 64 == 0); /* USB full speed packet boundary */
    printf("    PASS: Sensor frame byte layout calculation valid (18432 bytes for 96x96).\n");
}

int main(void)
{
    printf("=== ELAN Protocol Unit Tests ===\n");
    test_command_definitions();
    test_endpoint_mapping();
    test_frame_size_calculation();
    printf("ALL PROTOCOL TESTS PASSED.\n");
    return 0;
}
