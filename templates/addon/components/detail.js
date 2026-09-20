// components/detail.js —— 详情页
// 路由：$route('detail', { url: 'https://.../detail/1.html', title: '标题' })
// 思路：详情页解析出播放地址 → 做成按钮 → 点击跳到 video 组件

module.exports = {
  type: 'list',

  async fetch({ args }) {
    try {
      const resp = await $http.get(args.url, { headers: HEADERS, timeout: 15000 })
      const html = resp.data
      const $ = cheerio.load(html)

      // ---------- 1. 找播放地址 ----------
      const plays = []

      // a) maccms 的 player_aaaa 变量
      const mm = html.match(/player_aaaa\s*=\s*(\{[\s\S]*?\})/)
      if (mm) {
        try {
          const info = JSON.parse(mm[1])
          if (info.url) plays.push({ name: info.from || '默认线路', url: info.url })
        } catch (e) {}
      }

      // b) 页面里直接出现的 m3u8 / mp4
      if (!plays.length) {
        const re = /https?:\\?\/\\?\/[^"'\s\\]+?\.(?:m3u8|mp4)[^"'\s\\]*/gi
        let m2
        while ((m2 = re.exec(html)) !== null) {
          const u = m2[0].replace(/\\/g, '')
          if (!plays.some(x => x.url === u)) plays.push({ name: '线路' + (plays.length + 1), url: u })
        }
      }

      // ---------- 2. 基础信息 ----------
      const title = args.title || clean($('h1').text()) || '详情'
      const cover =
        $('.stui-content__thumb img').attr('data-original') ||
        $('.stui-content__thumb img').attr('src')
      const intro = clean($('.stui-content__detail').text())

      // ---------- 3. 组装 items ----------
      const items = []

      items.push({
        title: '简介',
        style: 'richContent',
        content: { url: args.url, html: '<p>' + (intro || title) + '</p>' }
      })

      if (!plays.length) {
        items.push({ title: '未找到播放地址，可尝试用网页打开', style: 'simple' })
      } else {
        plays.forEach(function (pl) {
          items.push({
            title: '▶ ' + pl.name,
            style: 'simple',
            image: $icon('play_circle_filled', 'blue'),
            onClick() {
              $router.to($route('play', { url: pl.url, title: title }))
            }
          })
        })
      }

      return {
        title: title,
        image: absUrl(cover),
        items: items
      }
    } catch (e) {
      console.error('[detail] error', e)
      this.error = '解析失败：' + e.message
      return { items: [] }
    }
  },

  actions: [
    {
      title: '用浏览器打开',
      onClick() {
        $ui.browser(this.args.url)
      }
    }
  ]
}
