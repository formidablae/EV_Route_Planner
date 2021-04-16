module.exports = {
    //...
    chainWebpack: config => {
        config.module
            .rule('raw')
            .test(/\.json$/)
            .use('raw-loader')
            .loader('raw-loader')
            .end()
    },
}