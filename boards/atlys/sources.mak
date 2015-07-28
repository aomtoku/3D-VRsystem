BOARD_SRC=$(wildcard $(BOARD_DIR)/top.v)

COMMON_SRC=$(wildcard $(CORES_DIR)/common/rtl/*.v)
COREGEN=$(wildcard $(CORES_DIR)/coregen/rtl/*.v)
MIXER_SRC=$(wildcard $(CORES_DIR)/video_mix/rtl/*.v)
MCB_SRC=$(wildcard $(CORES_DIR)/mcb_controller/*.v)
TMDS_RX_SRC=$(wildcard $(CORES_DIR)/rx/rtl/*.v)

TIMING_SRC=$(wildcard $(CORES_DIR)/timing/rtl/*.v)
TMDS_TX_SRC=$(wildcard $(CORES_DIR)/tx/rtl/*.v)
EDID_SRC=$(wildcard $(CORES_DIR)/i2c_edid/rtl/*.v)
LL151D_SRC=$(wildcard $(CORES_DIR)/ll151d/rtl/*.v)

CORES_SRC=$(COMMON_SRC) $(TIMING_SRC) $(TMDS_TX_SRC) $(COREGEN) $(TMDS_RX_SRC) $(MCB_SRC) $(MIXER_SRC) $(EDID_SRC)  $(LL151D_SRC)
