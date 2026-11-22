/**
 * @file driver.cpp
 * Runs the test screens of screens.st headless: scripted pointer and key input, one line per frame with the page,
 * the display list hash, the frame status and the wired variables. Frames marked for dumping are also rasterized;
 * their pixel hash is printed and, with a directory argument, their RGBA is written there.
 * Usage: driver [dump-dir]
 */
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "hmi_core.h"
#include "hmi_unit.hpp"

namespace {

constexpr int32_t kW = 480;
constexpr int32_t kH = 320;
/* Raster size of dumped frames; the data pages use a larger screen. */
int32_t g_w = kW;
int32_t g_h = kH;

strucpp::Configuration_HMICONFIG g_config;
uint32_t g_now;
const char *g_dump_dir;
/* Pixels of the last dumped frame. */
std::vector<uint8_t> g_px;

/* Element ids follow the order of Attach calls, across screens. */
enum : int32_t {
    kStart = 15, kRunSwitch, kSpeedSlider, kSetpointIn, kNameIn, kLocked,
    kPlant = 21, kPump = 27, kValve = 28,
    kBack = 36, kHome = 37,
    kToggle = 77, kJog = 78, kRinse = 82, kRecipes = 84, kBatcher = 85,
    kProbeFirst = 110, kPopupPick = 122,
};

uint64_t fnv(const uint8_t *p, size_t n) {
    uint64_t h = 1469598103934665603ull;
    for (size_t i = 0; i < n; i++) h = (h ^ p[i]) * 1099511628211ull;
    return h;
}

void frame(const char *label, bool dump = false) {
    hmi_set_time_ms(g_now);
    g_now += 40;
    hmi_frame_begin();
    g_config.HMIINST.run();
    size_t len = 0;
    const uint8_t *dl = hmi_frame_end(&len);
    std::printf("%s page=%d dl=%016llx status=%u run=%d held=%d clicks=%d pump=%d valve=%d speed=%.2f setpoint=%.3f "
                "name='%s' shows=%d hides=%d",
                label, (int)hmi_page(), (unsigned long long)hmi_frame_hash(), (unsigned)hmi_frame_status(),
                (int)strucpp::RUN.get(), (int)strucpp::HELD.get(), (int)strucpp::CLICKS.get(),
                (int)strucpp::PUMPON.get(), (int)strucpp::VALVEOPEN.get(), (double)strucpp::SPEED.get(),
                (double)strucpp::SETPOINT.get(), strucpp::NAME.get().c_str(), (int)strucpp::SHOWS.get(),
                (int)strucpp::HIDES.get());
    if (dump) {
        std::vector<uint8_t> px((size_t)g_w * g_h * 4);
        int rc = hmi_raster_render(dl, len, px.data(), g_w, g_h, g_w, 0, g_h, 256, 0, 0);
        std::printf(" raster=%d px=%016llx", rc, (unsigned long long)fnv(px.data(), px.size()));
        g_px = px;
        if (g_dump_dir) {
            std::string path = std::string(g_dump_dir) + "/" + label + ".rgba";
            FILE *f = std::fopen(path.c_str(), "wb");
            if (f) {
                int32_t wh[2] = {g_w, g_h};
                std::fwrite(wh, sizeof wh, 1, f);
                std::fwrite(px.data(), 1, px.size(), f);
                std::fclose(f);
            }
        }
    }
    std::printf("\n");
}

/* Centre of an element in lu, from the last frame's bounds; exits when the element was not drawn. */
void centre_of(int32_t id, int32_t *x, int32_t *y) {
    const int32_t *b = hmi_bounds_data();
    for (int i = 0; i < hmi_bounds_count(); i++, b += 5) {
        if (b[0] != id) continue;
        *x = (b[1] + b[3] / 2) / 16;
        *y = (b[2] + b[4] / 2) / 16;
        return;
    }
    std::printf("element %d not drawn\n", (int)id);
    std::exit(1);
}

void press(int32_t x, int32_t y) { hmi_input_pointer(HMI_PTR_DOWN, x * 16, y * 16); }
void move(int32_t x, int32_t y) { hmi_input_pointer(HMI_PTR_MOVE, x * 16, y * 16); }
void release(int32_t x, int32_t y) { hmi_input_pointer(HMI_PTR_UP, x * 16, y * 16); }

/* Press in one frame, release in the next. */
void tap_at(const char *label, int32_t x, int32_t y) {
    std::string down = std::string(label) + "_down", up = std::string(label) + "_up";
    press(x, y);
    frame(down.c_str());
    release(x, y);
    frame(up.c_str());
}

/* Rectangle of an element in lu, from the last frame's bounds; exits when the element was not drawn. */
void rect_of(int32_t id, int32_t *x, int32_t *y, int32_t *w, int32_t *h) {
    const int32_t *b = hmi_bounds_data();
    for (int i = 0; i < hmi_bounds_count(); i++, b += 5) {
        if (b[0] != id) continue;
        *x = b[1] / 16;
        *y = b[2] / 16;
        *w = b[3] / 16;
        *h = b[4] / 16;
        return;
    }
    std::printf("element %d not drawn\n", (int)id);
    std::exit(1);
}

void tap(const char *label, int32_t id) {
    int32_t x, y;
    centre_of(id, &x, &y);
    tap_at(label, x, y);
}

void keys(const char *text) {
    for (const char *c = text; *c; c++) hmi_input_key((uint32_t)(unsigned char)*c);
}

void show(int32_t page) { hmi_set_page(page); }

/* The input screen's variables. */
void inputs(const char *label) {
    std::printf("%s latch=%d jog=%d hoa=%d mode=%d rinse=%d recipe=%d batch=%.1f dial=%.1f\n", label,
                (int)strucpp::LATCH.get(), (int)strucpp::JOG.get(), (int)strucpp::HOA.get(), (int)strucpp::MODE.get(),
                (int)strucpp::RINSE.get(), (int)strucpp::RECIPE.get(), (double)strucpp::BATCH.get(),
                (double)strucpp::DIAL.get());
}

/* Seconds of 2024-10-20 plus a time of day, as DT nanoseconds. */
int64_t at(int h, int m, int sec) { return (int64_t)(20016 * 86400 + h * 3600 + m * 60 + sec) * 1000000000LL; }

void alarm(int i, bool active, bool acked, int severity, const char *message, int64_t raised, unsigned seq) {
    auto &a = strucpp::DEMOALARMS[i];
    a.USED.set(true);
    a.SEQ.set(seq);
    a.ACTIVE.set(active);
    a.ACKED.set(acked);
    a.SEVERITY.set((int16_t)severity);
    a.MESSAGE.set(message);
    a.RAISED.set(raised);
}

void summary(bool valid, bool acked, int severity, const char *message, int64_t raised, int count, int unacked,
             unsigned seq) {
    strucpp::SUMVALID.set(valid);
    strucpp::SUMSEQ.set(seq);
    strucpp::SUMACKED.set(acked);
    strucpp::SUMSEVERITY.set((int16_t)severity);
    strucpp::SUMMESSAGE.set(message);
    strucpp::SUMRAISED.set(raised);
    strucpp::SUMCOUNT.set(count);
    strucpp::SUMUNACKED.set(unacked);
}

void event(int i, unsigned seq, int kind, int severity, const char *message, int64_t stamp) {
    auto &e = strucpp::DEMOEVENTS[i];
    e.SEQ.set(seq);
    e.KIND.set((int16_t)kind);
    e.SEVERITY.set((int16_t)severity);
    e.MESSAGE.set(message);
    e.STAMP.set(stamp);
}

void demo_data() {
    alarm(0, true, false, 3, "Tank T-101 level high", at(10, 42, 7), 14);
    alarm(1, true, true, 2, "Pump P-101 discharge pressure low", at(10, 41, 55), 13);
    alarm(2, true, true, 1, "Filter F-2 differential pressure", at(10, 39, 12), 12);
    alarm(3, false, false, 3, "Motor M-3 overload trip", at(10, 31, 40), 11);
    summary(true, false, 3, "Tank T-101 level high (92.4 %)", at(10, 42, 7), 3, 2, 14);
    /* A ring of ten entries whose newest is entry 3: entries 4 to 9 are older, wrapping from the end. */
    const char *messages[] = {"Tank T-101 level high", "P-101 set to AUTO", "Pump P-101 discharge pressure low",
                              "Filter F-2 differential pressure", "Batch 2481 started (Tomato soup)",
                              "Motor M-3 overload trip", "Shift B signed in", "Mixer M-2 started", "CIP cycle done",
                              "Tank T-102 filled"};
    const int kinds[] = {1, 5, 1, 2, 4, 3, 5, 4, 4, 4};
    const int severities[] = {3, 0, 2, 1, 0, 3, 0, 0, 0, 0};
    for (int j = 0; j < 10; j++) {
        int slot = (3 - j + 10) % 10;
        event(slot, (unsigned)(20 - j), kinds[j], severities[j], messages[j], at(10, 42 - j, 7));
    }
    for (int i = 0; i <= 20; i++) {
        float q = (float)i * 5.0f;
        strucpp::CURVEX[i].set(q);
        strucpp::PUMPY[i].set(48.0f - 0.0036f * q * q - 0.06f * q);
        strucpp::SYSTEMY[i].set(6.0f + 0.0028f * q * q);
    }
}

void data_state(const char *label) {
    std::printf("%s acked_row=%d acked_row_seq=%u ack_top=%d ack_top_seq=%u ack_all=%d dialog_open=%d dialog_result=%d "
                "dialog_answers=%d\n",
                label, (int)strucpp::ACKEDROW.get(), (unsigned)strucpp::ACKEDROWSEQ.get(), (int)strucpp::ACKTOPHITS.get(),
                (unsigned)strucpp::ACKTOPSEQ.get(), (int)strucpp::ACKALLHITS.get(), (int)strucpp::DLGOPEN.get(),
                (int)strucpp::DLGRESULT.get(), (int)strucpp::DLGANSWERS.get());
}

/* The scale each probe of page 17 drew at, per mille. */
void scales(const char *label) {
    std::printf("%s k_slider=%d k_multilamp=%d k_readout=%d k_instrument=%d k_label=%d k_button=%d k_lamp=%d\n", label,
                (int)strucpp::KSLIDER.get(), (int)strucpp::KMULTI.get(), (int)strucpp::KREADOUT.get(),
                (int)strucpp::KINSTRUMENT.get(), (int)strucpp::KLABEL.get(), (int)strucpp::KBUTTON.get(),
                (int)strucpp::KLAMP.get());
}

/* Pixels in a band 2 to 6 lu outside an element's rectangle that differ from the screen background, in the last
   dumped frame: anything the element drew outside itself. */
int escaped(int32_t id) {
    int32_t x, y, w, h;
    rect_of(id, &x, &y, &w, &h);
    auto at = [](int32_t px, int32_t py) {
        uint32_t v;
        std::memcpy(&v, &g_px[((size_t)py * g_w + px) * 4], 4);
        return v;
    };
    uint32_t bg = at(g_w - 2, g_h - 2);
    int n = 0;
    for (int32_t py = y - 6; py <= y + h + 6; py++)
        for (int32_t px = x - 6; px <= x + w + 6; px++) {
            bool band = px <= x - 2 || px >= x + w + 1 || py <= y - 2 || py >= y + h + 1;
            bool inner = px > x - 2 && px < x + w + 1 && py > y - 2 && py < y + h + 1;
            if (!band || inner || px < 0 || py < 0 || px >= g_w || py >= g_h) continue;
            if (at(px, py) != bg) n++;
        }
    return n;
}

/* Probes of page 17 that drew outside themselves; exits when any did. */
void fits(const char *label) {
    const char *names[] = {"slider", "multilamp", "readout", "instrument", "label", "button", "lamp"};
    std::printf("%s escaped", label);
    int total = 0;
    for (int i = 0; i < 7; i++) {
        int n = escaped(kProbeFirst + i);
        total += n;
        std::printf(" %s=%d", names[i], n);
    }
    std::printf("\n");
    if (total != 0) {
        std::printf("%s: text escaped its widget\n", label);
        std::exit(1);
    }
}

void scaled(const char *page, int scale, bool dump = true) {
    strucpp::SCALE.set(scale);
    std::string label = std::string(page) + "_" + std::to_string(scale);
    frame((label + "_0").c_str());
    frame(label.c_str(), dump);
}

}  // namespace

int main(int argc, char **argv) {
    g_dump_dir = argc > 1 ? argv[1] : nullptr;
    hmi_core_init(kW, kH);

    /* Display widgets, the start screen. */
    strucpp::SPEED.set(123.4f);
    strucpp::LEVEL.set(6.25f);
    strucpp::FLOW.set(88.5f);
    frame("display_0");
    frame("display", true);

    /* Trend and vessel, values changing over time. */
    show(1);
    for (int i = 0; i < 24; i++) {
        strucpp::LEVEL.set(2.0f + (float)(i % 12) * 0.5f);
        strucpp::FLOW.set(60.0f + (float)i * 2.0f);
        frame(i == 23 ? "trend" : "trend_step", i == 23);
    }

    /* Controls: momentary button, switch, slider drag, numeric and text entry, a disabled switch. */
    show(2);
    frame("controls_0");
    frame("controls", true);
    tap("button", kStart);
    tap("switch", kRunSwitch);
    {
        int32_t x, y;
        centre_of(kSpeedSlider, &x, &y);
        press(x - 60, y);
        frame("slider_down");
        move(x + 40, y);
        frame("slider_move", true);
        release(x + 40, y);
        frame("slider_up");
    }
    tap("setpoint", kSetpointIn);
    frame("keyboard_numeric", true);
    keys("\b\b\b\b\b42.5\r");
    frame("setpoint_typed");
    tap("setpoint_again", kSetpointIn);
    /* Numeric keyboard at 480 x 320: key '7' at (125, 108), OK at (353, 270). */
    tap_at("key_7", 125, 108);
    tap_at("key_ok", 353, 270);
    tap("name", kNameIn);
    frame("keyboard_text", true);
    keys("\b\b\b\b\b\bPUMP STATION 7\r");
    frame("name_typed");
    tap("locked", kLocked);
    frame("controls_after", true);

    /* Diagram: pump and valve taps, pipe animation, panning a drawing larger than its room. */
    show(3);
    frame("diagram_0");
    frame("diagram", true);
    tap("pump", kPump);
    tap("valve", kValve);
    frame("diagram_flowing", true);
    {
        int32_t x, y;
        centre_of(kPlant, &x, &y);
        press(x, y + 60);
        frame("pan_down");
        move(x - 120, y);
        frame("pan_move");
        release(x - 120, y);
        frame("pan_up", true);
    }

    /* Layout within limits, floating element. */
    show(4);
    frame("layout_0");
    frame("layout", true);
    std::printf("layout w1=%d w2=%d w3=%d x4=%d\n", (int)strucpp::LAYOUTW1.get(), (int)strucpp::LAYOUTW2.get(),
                (int)strucpp::LAYOUTW3.get(), (int)strucpp::LAYOUTX4.get());

    /* Navigation: show and hide hooks, back, home. */
    show(5);
    frame("nav_0");
    frame("nav");
    tap("back", kBack);
    frame("after_back");
    show(5);
    frame("nav_again");
    tap("home", kHome);
    frame("after_home");

    /* A diagram squeezed to no height still takes a press without failing. */
    show(6);
    frame("squeezed_0");
    tap_at("squeezed", 12, 12);
    frame("squeezed_after");

    /* Shapes and animation: frames 40 ms apart turn the fan and pump, move the belts and flash the lamp. */
    show(7);
    frame("motion_0", true);
    for (int i = 1; i < 7; i++) frame(i == 3 ? "motion_120ms" : "motion_step", i == 3);
    frame("motion_280ms", true);

    /* Nested stacks: the tank on the left, the buttons top to bottom on its right. */
    show(8);
    frame("nested_0");
    frame("nested", true);
    std::printf("nested tank_x=%d tank_w=%d side_x=%d fill_x=%d fill_y=%d drain_y=%d\n",
                (int)strucpp::NESTTANKX.get(), (int)strucpp::NESTTANKW.get(), (int)strucpp::NESTSIDEX.get(),
                (int)strucpp::NESTFILLX.get(), (int)strucpp::NESTFILLY.get(), (int)strucpp::NESTDRAINY.get());

    /* Indicators, then the thermometer, a level meter and the clock and date of a fixed DT. */
    show(9);
    frame("indicators_0");
    frame("indicators", true);
    show(10);
    frame("time_0");
    frame("time", true);

    /* Latching, selecting and stepping controls; the drop-down list opens over the screen and scrolls. */
    show(11);
    frame("inputs_0");
    frame("inputs", true);
    tap("toggle", kToggle);
    inputs("toggle");
    {
        int32_t x, y;
        centre_of(kJog, &x, &y);
        press(x, y);
        frame("jog_down");
        frame("jog_lit", true);
        inputs("jog_held");
        release(x, y);
        frame("jog_up");
        inputs("jog_released");
    }
    tap_at("hand_right", 350, 80);
    tap_at("hand_right2", 350, 80);
    inputs("hand_auto");
    tap_at("hand_left", 260, 80);
    inputs("hand_off");
    tap_at("mode_off", 212, 132);
    tap("rinse", kRinse);
    inputs("mode_rinse");
    /* Drop-down at 480 x 320: the list opens above the field, 4 of 6 rows from (20, 20), 32 lu each. */
    tap("recipe_open", kRecipes);
    frame("recipe_list", true);
    press(100, 100);
    frame("recipe_press");
    move(100, 36);
    frame("recipe_scrolled", true);
    release(100, 36);
    frame("recipe_drag_up");
    inputs("recipe_after_drag");
    tap_at("recipe_pick", 100, 136);
    frame("recipe_closed", true);
    inputs("recipe_picked");
    tap("recipe_reopen", kRecipes);
    tap_at("recipe_outside", 440, 300);
    frame("recipe_dismissed");
    inputs("recipe_dismissed");
    /* Stepper: plus at (347, 202), held for repeats; then minus at (214, 202). */
    press(347, 202);
    for (int i = 0; i < 20; i++) frame(i == 19 ? "batch_held" : "batch_hold", i == 19);
    release(347, 202);
    frame("batch_up");
    inputs("batch_repeat");
    tap_at("batch_minus", 214, 202);
    inputs("batch_minus");
    /* Knob centred at (420, 203): pointing right is 83 %, snapped to 85; straight up is 50. */
    press(450, 203);
    frame("dial_down");
    inputs("dial_right");
    move(420, 170);
    frame("dial_move", true);
    release(420, 170);
    frame("dial_up");
    inputs("dial_up");

    /* Process symbols joined by pipes at their ports. */
    show(12);
    frame("symbols_0");
    frame("symbols", true);

    /* A second viewer starts on the start page with its own state. */
    hmi_session_t *viewer = hmi_session_create();
    hmi_session_use(viewer);
    hmi_core_init(320, 240);
    frame("viewer2", true);
    hmi_session_use(nullptr);
    hmi_session_destroy(viewer);
    frame("viewer1_after");

    /* An entry outside the numeric input's 0 to 100 is refused: the keyboard closes, the setpoint stays. */
    show(2);
    frame("range_0");
    tap("setpoint_range", kSetpointIn);
    keys("\b\b\b\b\b\b\b\b30000\r");
    frame("setpoint_out_of_range");
    tap("setpoint_range_low", kSetpointIn);
    keys("\b\b\b\b\b\b\b\b-1\r");
    frame("setpoint_below_range");
    tap("setpoint_range_in", kSetpointIn);
    keys("\b\b\b\b\b\b\b\b100\r");
    frame("setpoint_at_max", true);
    /* Data widgets on a larger screen of their own viewer, each page at 1x, 1.5x and 2x. */
    hmi_session_t *data = hmi_session_create();
    hmi_session_use(data);
    hmi_core_init(1100, 760);
    g_w = 1100;
    g_h = 760;
    demo_data();
    frame("data_start");
    show(13);
    for (int s : {1000, 1500, 2000}) scaled("alarms", s);
    strucpp::SCALE.set(1000);
    summary(true, false, 2, "Pump P-101 discharge pressure low", at(10, 41, 55), 3, 2, 13);
    frame("banner_medium", true);
    summary(true, true, 1, "Filter F-2 differential pressure", at(10, 39, 12), 1, 0, 12);
    frame("banner_low_acked", true);
    summary(false, false, 0, "", 0, 0, 0, 0);
    frame("banner_none", true);
    summary(true, false, 3, "Tank T-101 level high (92.4 %)", at(10, 42, 7), 3, 2, 14);
    frame("banner_high");
    /* Banner ACK at its button, 6 lu in from the right, then the list's Ack all and filter in its footer. */
    tap_at("banner_ack", strucpp::BANNERX.get() + strucpp::BANNERW.get() - 37, strucpp::BANNERY.get() + 17);
    {
        int32_t lx = strucpp::LISTX.get(), ly = strucpp::LISTY.get(), lh = strucpp::LISTH.get();
        tap_at("list_ack_all", lx + 50, ly + lh - 17);
        tap_at("list_filter", lx + 160, ly + lh - 17);
        frame("list_active_only", true);
        tap_at("list_filter_off", lx + 160, ly + lh - 17);
        /* The first row's Ack, 50 lu in from the right, 6 lu below its top. */
        tap_at("list_ack_row", lx + strucpp::LISTW.get() - 29, ly + 30 + 17);
        frame("list_acked", true);
        data_state("list_acks");
        /* Eight alarms: the list scrolls by a drag up. */
        alarm(4, true, false, 2, "Valve V-12 not closed", at(10, 44, 1), 16);
        alarm(5, true, false, 1, "Cooling water flow low", at(10, 45, 30), 17);
        alarm(6, false, false, 2, "Agitator A-1 vibration", at(10, 20, 0), 15);
        alarm(7, true, true, 3, "Emergency stop pressed", at(10, 46, 12), 18);
        frame("list_full", true);
        press(lx + 260, ly + 30 + 80);
        frame("list_press");
        move(lx + 260, ly + 30 + 10);
        frame("list_drag");
        release(lx + 260, ly + 30 + 10);
        frame("list_scrolled", true);
    }
    show(14);
    for (int s : {1000, 1500, 2000}) scaled("log", s);
    strucpp::SCALE.set(1000);
    frame("log_0");
    press(strucpp::LOGX.get() + 200, strucpp::LOGY.get() + 150);
    frame("log_press");
    move(strucpp::LOGX.get() + 200, strucpp::LOGY.get() + 40);
    frame("log_drag");
    release(strucpp::LOGX.get() + 200, strucpp::LOGY.get() + 40);
    frame("log_scrolled", true);
    show(15);
    for (int s : {1000, 1500, 2000}) scaled("plot", s);
    show(16);
    strucpp::DLGOPEN.set(true);
    for (int s : {1000, 1500, 2000}) scaled("dialog", s);
    strucpp::SCALE.set(1000);
    frame("dialog_0");
    /* The box is centred, 260 x 140: Start, the last button, 12 lu in from its right and 14 lu up from its bottom. */
    tap_at("dialog_start", (1100 - 260) / 2 + 260 - 12 - 35, (760 - 140) / 2 + 140 - 14 - 16);
    frame("dialog_closed", true);
    data_state("dialog_answered");

    /* Acknowledging by occurrence. The banner drew alarm 14; a newer alarm takes the top before the ACK is tapped: the
       banner reports the Seq it drew. */
    show(13);
    summary(true, false, 3, "Tank T-101 level high (92.4 %)", at(10, 42, 7), 3, 2, 14);
    frame("seq_banner_0");
    frame("seq_banner");
    summary(true, false, 2, "Valve V-12 not closed", at(10, 47, 0), 4, 3, 19);
    tap_at("seq_banner_ack", strucpp::BANNERX.get() + strucpp::BANNERW.get() - 37, strucpp::BANNERY.get() + 17);
    data_state("seq_banner_acked");
    {
        int32_t lx = strucpp::LISTX.get(), ly = strucpp::LISTY.get(), lw = strucpp::LISTW.get();
        /* Back to the top of the list: Emergency stop (acked), then Cooling water (alarm 5, Seq 17) with its Ack. */
        press(lx + 260, ly + 30 + 10);
        frame("seq_list_press");
        move(lx + 260, ly + 30 + 200);
        frame("seq_list_drag");
        release(lx + 260, ly + 30 + 200);
        frame("seq_list_top", true);
        /* Row 5 is freed and taken by a new alarm before the Ack lands: the list reports the Seq it drew, 17. */
        alarm(5, true, false, 1, "Cooling water flow low", at(10, 45, 30), 20);
        tap_at("seq_list_reused", lx + lw - 29, ly + 30 + 34 + 17);
        data_state("seq_list_not_acked");
        std::printf("seq_list_row5 acked=%d seq=%u\n", (int)strucpp::DEMOALARMS[5].ACKED.get(),
                    (unsigned)strucpp::DEMOALARMS[5].SEQ.get());
        /* Once drawn, the new alarm's Ack carries its own Seq. */
        tap_at("seq_list_new", lx + lw - 29, ly + 30 + 34 + 17);
        data_state("seq_list_acked");
        std::printf("seq_list_row5 acked=%d seq=%u\n", (int)strucpp::DEMOALARMS[5].ACKED.get(),
                    (unsigned)strucpp::DEMOALARMS[5].SEQ.get());
    }
    hmi_session_use(nullptr);
    hmi_session_destroy(data);
    g_w = kW;
    g_h = kH;

    /* A tap on the stepper's caption band does not step the value. */
    show(11);
    frame("caption_0");
    {
        int32_t x, y, w, h;
        rect_of(kBatcher, &x, &y, &w, &h);
        tap_at("batch_caption", x + 10, y + 8);
        inputs("batch_caption");
        tap_at("batch_minus_again", x + 10, y + h - 10);
        inputs("batch_minus_again");
    }

    /* Fixed-size widgets keep their scale while their text or value changes, a text that would not fit shrinks, and
       nothing is drawn outside them; the Auto slider in a tall box is drawn vertical at the scale of that orientation. */
    show(17);
    frame("scale_0");
    frame("scale_short", true);
    scales("scale_short");
    fits("scale_short");
    strucpp::PROBESTATE.set(1);
    strucpp::PROBEVALUE.set(12345.6f);
    strucpp::PROBETEXT.set("Running with full load");
    frame("scale_long_0");
    frame("scale_long", true);
    scales("scale_long");
    fits("scale_long");
    strucpp::PROBESTATE.set(2);
    strucpp::PROBEVALUE.set(-0.5f);
    strucpp::PROBETEXT.set("-");
    frame("scale_tiny_0");
    frame("scale_tiny", true);
    scales("scale_tiny");
    fits("scale_tiny");

    /* Pop-ups of a diagram drawn at about half size open on the screen at the field's size; the dialog dims the whole
       screen with its box centred. */
    show(18);
    frame("popup_0");
    frame("popup", true);
    {
        int32_t x, y, w, h;
        rect_of(kPopupPick, &x, &y, &w, &h);
        std::printf("popup_field x=%d y=%d w=%d h=%d\n", (int)x, (int)y, (int)w, (int)h);
        tap_at("popup_open", x + w / 2, y + h / 2);
        frame("popup_list", true);
        /* The list opens under the field at the field's scale on screen, h / 60 lu per lu: 4 down, a 4 pad, rows of 32. */
        tap_at("popup_pick", x + w / 2, y + h + (4 + 4 + 32 + 16) * h / 60);
        frame("popup_picked");
        std::printf("popup_pick value=%d\n", (int)strucpp::POPPICK.get());
    }
    strucpp::POPOPEN.set(true);
    frame("popup_dialog_0");
    frame("popup_dialog", true);
    /* The box is 440 x 140 centred on the 480 x 320 screen: Start 12 lu in from its right, 14 lu up from its bottom. */
    tap_at("popup_dialog_start", (480 - 440) / 2 + 440 - 12 - 35, (320 - 140) / 2 + 140 - 14 - 16);
    frame("popup_dialog_closed");
    std::printf("popup_dialog open=%d result=%d answers=%d\n", (int)strucpp::POPOPEN.get(), (int)strucpp::POPRESULT.get(),
                (int)strucpp::POPANSWERS.get());
    return 0;
}
