// components/index.js —— 列表页
// 数据源：https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=8&mkt=zh-CN

module.exports = {
  type: 'list',
  title: '必应每日壁纸',
  translucent: true,

  async fetch({ page }) {
    // 分页：页号从 1 开始，接口用 idx 偏移
    const p = page || 1
    const perPage = Math.min(Math.max($prefs.get('perPage') || 8, 1), 8)
    const idx = (p - 1) * perPage
    const mkt = getMkt()

    const url =
      API + '/HPImageArchive.aspx?format=js&idx=' + idx + '&n=' + perPage + '&mkt=' + mkt
    console.log('[bing] GET', url)

    try {
      const resp = await $http.get(url, { headers: HEADERS, timeout: 15000 })
      const images = (resp.data && resp.data.images) || []

      const items = images.map(function (img) {
        // img.url 形如 /th?id=OHR.xxx_1920x1080.jpg&rf=...；加 w/h 参数可拿不同尺寸
        const full = API + img.url.split('&')[0] + '&w=1920&h=1080'
        const thumb = API + (img.urlbase || img.url) + '_400x240.jpg'

        return {
          title: (img.title || '').trim(),
          style: 'gallery',
          image: thumb,
          summary: (img.copyright || '').replace(/\(.*?\)/g, '').trim(),
          label: formatDate(img.startdate),
          time: formatDate(img.startdate),
          // ★ 核心技巧：直接把 args 交给内置 image 组件，不用自己写页面
          route: $route('@image', {
            url: full,
            title: (img.title || '').trim()
          })
        }
      })

      // 接口最多只返回最近 8*N 天，超出就不再有下一页
      const nextPage = images.length > 0 ? p + 1 : null

      return {
        subtitle: '地区：' + mkt,
        nextPage: nextPage,
        items: items
      }
    } catch (e) {
      console.error('[bing] error', e)
      this.error = '加载失败：' + e.message
      return { items: [] }
    }
  },

  actions: [
    {
      title: '切换地区',
      async onClick() {
        const cur = getMkt()
        const option = await $input.select({
          title: '选择壁纸地区',
          options: [
            { title: '中国', value: 'zh-CN' },
            { title: '美国', value: 'en-US' },
            { title: '日本', value: 'ja-JP' },
            { title: '英国', value: 'en-GB' },
            { title: '德国', value: 'de-DE' }
          ]
        })
        if (option && option.value !== cur) {
          $prefs.set('mkt', option.value)
          $ui.toast('已切换到 ' + option.title)
          this.refresh()
        }
      }
    },
    {
      title: '打开必应',
      onClick() {
        $ui.browser('https://www.bing.com')
      }
    }
  ]
}