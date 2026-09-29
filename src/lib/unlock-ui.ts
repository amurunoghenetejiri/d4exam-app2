/**
 * Release stuck UI locks (Radix scroll-lock, pointer-events:none, stray inert)
 * that can freeze the Android WebView after overlays close mid-navigation.
 * Skips anything while a Radix dialog/sheet is genuinely open or the lock gate is active.
 */
export function forceUnlockBody(): void {
  if (typeof document === "undefined") return;
  try {
    const openOverlay = document.querySelector(
      '[role="dialog"][data-state="open"], [data-radix-popper-content-wrapper]',
    );
    const lockGate = document.querySelector("[data-d4-lock-gate]");
    const root = document.getElementById("root");
    root?.removeAttribute("inert");
    if (root) root.style.pointerEvents = "";
    if (!lockGate) {
      document.querySelectorAll("[inert]").forEach((el) => el.removeAttribute("inert"));
    }
    if (openOverlay) return;
    document.body.removeAttribute("data-scroll-locked");
    document.documentElement.removeAttribute("data-scroll-locked");
    document.body.style.overflow = "";
    document.documentElement.style.overflow = "";
    document.body.style.pointerEvents = "";
    document.documentElement.style.pointerEvents = "";
  } catch {
    /* ignore */
  }
}
