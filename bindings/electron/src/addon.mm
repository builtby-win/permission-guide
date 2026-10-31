// N-API addon over the permission-guide C ABI. pg_present's callback fires on the main thread;
// it is forwarded to JS through a threadsafe function (the Node main thread in Electron IS the
// AppKit main thread, so the panel and callback live on the same loop).
#include <napi.h>
#include <string>
#include "permission_guide.h"

namespace {

struct PresentCtx {
  Napi::Promise::Deferred deferred;
  Napi::ThreadSafeFunction tsfn;
  bool granted = false;
};

Napi::Value Status(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();
  if (info.Length() < 1 || !info[0].IsNumber()) {
    Napi::TypeError::New(env, "status(kind: number)").ThrowAsJavaScriptException();
    return env.Undefined();
  }
  return Napi::Boolean::New(env, pg_status(info[0].As<Napi::Number>().Int32Value()) != 0);
}

// present(kind, appPath | null, appName | null) -> Promise<boolean>
Napi::Value Present(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();
  if (info.Length() < 1 || !info[0].IsNumber()) {
    Napi::TypeError::New(env, "present(kind: number, appPath?, appName?)").ThrowAsJavaScriptException();
    return env.Undefined();
  }
  int kind = info[0].As<Napi::Number>().Int32Value();
  std::string path, name;
  bool hasPath = info.Length() > 1 && info[1].IsString();
  bool hasName = info.Length() > 2 && info[2].IsString();
  if (hasPath) path = info[1].As<Napi::String>().Utf8Value();
  if (hasName) name = info[2].As<Napi::String>().Utf8Value();

  auto *ctx = new PresentCtx{Napi::Promise::Deferred::New(env), {}};
  ctx->tsfn = Napi::ThreadSafeFunction::New(
      env, Napi::Function::New(env, [](const Napi::CallbackInfo &) {}), "permission-guide", 0, 1);
  Napi::Promise promise = ctx->deferred.Promise();

  pg_present(kind, hasPath ? path.c_str() : nullptr, hasName ? name.c_str() : nullptr,
             [](int granted, void *p) {
               auto *c = static_cast<PresentCtx *>(p);
               c->granted = granted != 0;
               Napi::ThreadSafeFunction t = c->tsfn;  // copy: c is deleted by the queued call
               t.NonBlockingCall(c, [](Napi::Env env, Napi::Function, PresentCtx *c) {
                 c->deferred.Resolve(Napi::Boolean::New(env, c->granted));
                 delete c;
               });
               t.Release();
             },
             ctx);
  return promise;
}

Napi::Value Dismiss(const Napi::CallbackInfo &info) {
  pg_dismiss();
  return info.Env().Undefined();
}

Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports.Set("status", Napi::Function::New(env, Status));
  exports.Set("present", Napi::Function::New(env, Present));
  exports.Set("dismiss", Napi::Function::New(env, Dismiss));
  return exports;
}

}  // namespace

NODE_API_MODULE(permission_guide, Init)
