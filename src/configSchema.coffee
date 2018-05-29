module.exports =
  cache: 
    types: [Number, Boolean]
    default: (process.env?.NODE_ENV == "production")*Math.pow(2,16) # 64 kB
    _default: "if inProduction then 65536 else false"
    desc: "Maximum filesize to cache"
  cacheFile:
    types: [String, Boolean]
    default: "./.leajs-cache.json"
    desc: "default file to save cache on exit. Set False to disable."