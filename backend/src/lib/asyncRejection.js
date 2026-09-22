import express from 'express';
import methods from 'methods';

/**
 * §19: Express 4 ignores a rejected promise returned by a handler. The request
 * then hangs until the proxy 502s, with nothing in the log — the single most
 * expensive failure mode on the previous app.
 *
 * Wrapping each route by hand fails the moment somebody forgets, so this patches
 * the registration methods themselves. Call it once, before any route is
 * registered; afterwards an `async` handler that throws reaches the error
 * middleware like a synchronous one.
 *
 * Express 4 keeps its route-registration methods on two prototypes: the Router
 * proto (used by every `express.Router()`) and the application proto.
 */

const REGISTRARS = [...methods, 'all', 'use'];

function wrapHandler(handler) {
  if (typeof handler !== 'function') return handler;
  if (handler.__asyncForwarded) return handler;

  // Error middleware is identified by arity, so the wrapper must preserve it.
  const wrapped = handler.length === 4
    ? function (err, req, res, next) {
        try {
          return Promise.resolve(handler.call(this, err, req, res, next)).catch(next);
        } catch (thrown) {
          return next(thrown);
        }
      }
    : function (req, res, next) {
        try {
          return Promise.resolve(handler.call(this, req, res, next)).catch(next);
        } catch (thrown) {
          return next(thrown);
        }
      };

  Object.defineProperty(wrapped, 'name', { value: handler.name, configurable: true });
  wrapped.__asyncForwarded = true;
  return wrapped;
}

function patch(proto, label) {
  for (const name of REGISTRARS) {
    const original = proto[name];
    if (typeof original !== 'function' || original.__asyncPatched) continue;

    proto[name] = function (...args) {
      // A leading path/array/RegExp is passed through untouched; only the
      // handler functions are wrapped.
      const mapped = args.map((arg) => {
        if (typeof arg === 'function') return wrapHandler(arg);
        if (Array.isArray(arg)) return arg.map(wrapHandler);
        return arg;
      });
      return original.apply(this, mapped);
    };
    proto[name].__asyncPatched = true;
    proto[name].__label = label;
  }
}

let installed = false;

export function installAsyncRejectionForwarding() {
  if (installed) return;
  patch(express.Router, 'router');
  patch(express.application, 'application');
  installed = true;
}
