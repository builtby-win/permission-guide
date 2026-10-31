#ifndef PERMISSION_GUIDE_H
#define PERMISSION_GUIDE_H

#ifdef __cplusplus
extern "C" {
#endif

/* kind: 0 accessibility, 1 screen recording, 2 input monitoring.
   All functions are callable from any thread. */

/* Returns 1 if granted, 0 otherwise. */
int pg_status(int kind);

/* Shows the docked guide. app_path / app_name may be NULL (defaults to the
   main bundle). cb(granted, ctx) fires once, on the main thread:
   granted=1 on grant, 0 on dismiss. cb may be NULL. */
void pg_present(int kind, const char *app_path, const char *app_name,
                void (*cb)(int granted, void *ctx), void *ctx);

void pg_dismiss(void);

#ifdef __cplusplus
}
#endif
#endif
