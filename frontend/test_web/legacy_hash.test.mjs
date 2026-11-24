// Prueba del script de compatibilidad de web/index.html: los enlaces viejos con
// # (/#/primer-ingreso?token=X) pasan a la ruta sin # antes de arrancar Flutter.
// Corre con `node --test test_web/` desde frontend/, sin dependencias.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const INICIO = '<!-- legacy-hash:inicio -->';
const FIN = '<!-- legacy-hash:fin -->';

/** El JavaScript que hay entre los marcadores de web/index.html. */
function scriptDeCompatibilidad() {
  const html = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8');
  const desde = html.indexOf(INICIO);
  const hasta = html.indexOf(FIN);
  assert.ok(desde >= 0 && hasta > desde, 'faltan los marcadores legacy-hash en web/index.html');
  const bloque = html.slice(desde + INICIO.length, hasta);
  const coincidencia = bloque.match(/<script>([\s\S]*?)<\/script>/);
  assert.ok(coincidencia, 'no hay un <script> entre los marcadores');
  return coincidencia[1];
}

/**
 * Ejecuta el script contra un window simulado y devuelve las llamadas a
 * replaceState. Con `lanza` el replaceState falla, como en un cambio de origen.
 */
function ejecutar({ pathname = '/', hash = '', lanza = false } = {}) {
  const llamadas = [];
  const window = {
    location: { pathname, hash },
    history: {
      replaceState(...argumentos) {
        llamadas.push(argumentos);
        if (lanza) throw new Error('SecurityError');
      },
    },
  };
  vm.runInNewContext(scriptDeCompatibilidad(), { window });
  return llamadas;
}

test('#/primer-ingreso?token=X con pathname / pasa a /primer-ingreso?token=X', () => {
  assert.deepEqual(ejecutar({ hash: '#/primer-ingreso?token=X' }), [
    [null, '', '/primer-ingreso?token=X'],
  ]);
});

test('#/socio/avisos pasa a /socio/avisos', () => {
  assert.deepEqual(ejecutar({ hash: '#/socio/avisos' }), [[null, '', '/socio/avisos']]);
});

test('#/recuperacion?token=a%2Fb conserva el escape', () => {
  assert.deepEqual(ejecutar({ hash: '#/recuperacion?token=a%2Fb' }), [
    [null, '', '/recuperacion?token=a%2Fb'],
  ]);
});

test('un # sin barra no se toca', () => {
  assert.deepEqual(ejecutar({ hash: '#seccion' }), []);
  assert.deepEqual(ejecutar({ hash: '#' }), []);
});

test('#//evil.com no se toca', () => {
  assert.deepEqual(ejecutar({ hash: '#//evil.com' }), []);
});

test('#/\\evil.com no se toca', () => {
  assert.deepEqual(ejecutar({ hash: '#/\\evil.com' }), []);
});

test('sin fragmento no se toca', () => {
  assert.deepEqual(ejecutar({ hash: '' }), []);
});

test('con un pathname distinto de / no se toca', () => {
  assert.deepEqual(ejecutar({ pathname: '/socio/avisos', hash: '#/primer-ingreso?token=X' }), []);
  assert.deepEqual(ejecutar({ pathname: '/index.html', hash: '#/login' }), []);
});

test('si replaceState lanza, el script no rompe', () => {
  assert.doesNotThrow(() => ejecutar({ hash: '#/primer-ingreso?token=X', lanza: true }));
});
