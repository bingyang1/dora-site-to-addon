// components/play.js —— 视频播放
// 路由：$route('play', { url: 'https://.../index.m3u8', title: '标题' })
// 因为已知播放地址，这里直接把 args 交给内置 video 组件即可。

module.exports = {
  type: 'video',
  async fetch({ args }) {
    let url = args.url
    if (url && !/^https?:/i.test(url)) url = absUrl(url)
    console.log('[play]', url)
    return {
      title: args.title || '播放中',
      image: args.image || null,
      url: url,
      headers: HEADERS
    }
  }
}