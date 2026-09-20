// scripts/dom.js —— 注入到 WebView 页面里的脚本
// 用法：webview 组件里写 script: 'dom.js'
// 作用：从页面里嗅探真实的媒体地址，通过 $dora.sendEvent 回传给组件

;(function () {
  if (window.__dora_hooked__) return
  window.__dora_hooked__ = true

  function send(url, kind) {
    if (!url) return
    try {
      $dora.sendEvent('media', { url: url, kind: kind || 'unknown', page: location.href })
    } catch (e) {}
  }

  // 1) 监听 <video> 元素
  var last = ''
  setInterval(function () {
    var v = document.querySelector('video')
    if (v) {
      var src = v.currentSrc || v.src
      if (src && src !== last && src.indexOf('blob:') !== 0) {
        last = src
        send(src, 'video')
      }
    }
  }, 1200)

  // 2) 劫持 XHR，抓 m3u8 / mp4
  var rawOpen = XMLHttpRequest.prototype.open
  XMLHttpRequest.prototype.open = function (method, url) {
    try {
      if (/\.m3u8|\.mp4|\.flv|m3u8|playurl/i.test(url)) send(url, 'xhr')
    } catch (e) {}
    return rawOpen.apply(this, arguments)
  }

  // 3) 劫持 fetch
  if (window.fetch) {
    var rawFetch = window.fetch
    window.fetch = function (input) {
      try {
        var u = typeof input === 'string' ? input : (input && input.url) || ''
        if (/\.m3u8|\.mp4|\.flv/i.test(u)) send(u, 'fetch')
      } catch (e) {}
      return rawFetch.apply(this, arguments)
    }
  }

  console.log('[dora] dom.js injected')
})()