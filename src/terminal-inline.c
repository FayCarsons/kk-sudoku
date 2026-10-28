// POSIX primitives for terminal.kk: raw mode, timed byte reads, flushing and
// window size
#include <poll.h>
#include <stdbool.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

static struct termios kk_tty_saved;
static bool kk_tty_is_raw = false;

// Turn off line buffering, echo and signal keys; false when stdin or stdout is
// not a terminal
static bool kk_tty_raw_mode(kk_context_t *ctx) {
  if (kk_tty_is_raw)
    return true;
  if (!isatty(STDIN_FILENO) || !isatty(STDOUT_FILENO))
    return false;
  if (tcgetattr(STDIN_FILENO, &kk_tty_saved) != 0)
    return false;
  struct termios raw = kk_tty_saved;
  raw.c_iflag &= ~(IXON | ICRNL);
  raw.c_lflag &= ~(ICANON | ECHO | ISIG | IEXTEN);
  raw.c_cc[VMIN] = 1;
  raw.c_cc[VTIME] = 0;
  if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) != 0)
    return false;
  kk_tty_is_raw = true;
  return true;
}

static kk_unit_t kk_tty_restore_mode(kk_context_t *ctx) {
  if (kk_tty_is_raw) {
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &kk_tty_saved);
    kk_tty_is_raw = false;
  }
  return kk_Unit;
}

// The next input byte, or -1 when none arrives within `timeout_ms`; a negative
// timeout waits forever
static int32_t kk_tty_read_byte(int32_t timeout_ms, kk_context_t *ctx) {
  struct pollfd input = {.fd = STDIN_FILENO, .events = POLLIN};
  if (poll(&input, 1, timeout_ms) <= 0)
    return -1;
  unsigned char byte;
  return read(STDIN_FILENO, &byte, 1) == 1 ? byte : -1;
}

static kk_unit_t kk_tty_flush(kk_context_t *ctx) {
  fflush(stdout);
  return kk_Unit;
}

static int32_t kk_tty_columns(kk_context_t *ctx) {
  struct winsize size;
  return ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0 ? size.ws_col : -1;
}

static int32_t kk_tty_rows(kk_context_t *ctx) {
  struct winsize size;
  return ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0 ? size.ws_row : -1;
}
