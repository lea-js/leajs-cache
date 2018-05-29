

module.exports = ({init, position}) => 
  init.hookIn position.init, (leajs) =>
    leajs.cache =
      save: 
        head: perm: false
        lastModified: perm: false
      select: []
  init.hookIn ({
    config: {cache, cacheFile},
    cache: {save, select}
    fs:{stat,readJson,outputJsonSync}, 
    path:{resolve},
    util:{isString}
    Promise,
    respond
    }) =>

    if cache
      chokidar = require "chokidar"
      crypto = require "crypto"
      watch = (val, element) =>

        if element.watch != false
          chokidar.watch val, persistent: false, ignoreInitial: true
          .on "all", =>
            for k,v of save
              delete element[k] unless v.perm
            delete element.body
            delete element.statusCode
        return val
                
      save.dependencies =
        perm: true
        deserialize: watch

      lookUp = {}

      if cacheFile and isString(cacheFile)
        cacheFile = resolve(cacheFile) 
        lastChanged = {}
        getLastChanged = (file) => 
          lastChanged[file] ?= await stat(file)
            .then (stats) => stats.mtime
            .catch => new Date()
        isValid = (el) =>
          if el.dependencies?.length > 0
            return el.lastModified >= await Promise.all el.dependencies.map getLastChanged
          else
            return true
        # read cache file
        readJson cacheFile
        .then (result) =>
          for url,arr of result
            result[url] = arr.map (el) =>
              el.lastModified = new Date el.lastModified
              if await isValid(el)
                for k,v of save
                  el[k] = des(tmp,el) if (tmp  = el[k])? and (des = v?.deserialize)?
                if (body = el.body)?
                  if body.type == "Buffer" 
                    el.body = Buffer.from(body.data)
                return el
              else
                return null
          for url of result
            result[url] = await Promise.all(result[url])
              .then (arr) => arr.filter (val) => val?
          lookUp = result
        .catch =>
        # write cache file
        process.on "exit", =>
          for url,arr of lookUp
            for el in arr
              for k,v of save
                el[k] = ser(tmp,el) if (tmp = el[k])? and (ser = v?.serialize)?
          outputJsonSync cacheFile, lookUp

      # select cache entry
      respond.hookIn position.before, (req) =>
        if (arr = lookUp[req.url])?
          for selector in select
            arr = selector(arr, req)
          tmp = arr[0]
        if tmp?
          if tmp.head? and tmp.head.etag == req.request.headers["if-none-match"]
            throw statusCode: 304
          else
            Object.assign req, tmp
            req.head = Object.assign {}, tmp.head if tmp.head?
            req.cacheObj = tmp

      respond.hookIn position.end, (req) =>
        if not req.head.etag? and req.statusCode == 200
          # body generation
          body = null
          bodyvalid = true
          bodylen = 0
          req.chunk.hookIn req.position.end, ({chunk}) =>
            hash.update(chunk)
            if bodyvalid
              chunk = Buffer.from(chunk) unless Buffer.isBuffer(chunk)
              unless body?
                body = chunk
                bodylen = chunk.length
              else
                bodylen += chunk.length
                if bodylen > cache
                  bodyvalid = false
                else
                  body = Buffer.concat [body,chunk], bodylen
          req.end.hookIn =>
            if bodyvalid
              req.body = body
            else
              delete req.body

          # etag generation
          hash = crypto.createHash("sha1")
          req.trailers ?= {}
          req.trailers.etag = new Promise (resolve) =>
            req.end.hookIn => 
              head = req.head
              if head.trailer?
                head.trailer = head.trailer.replace /etag,?/, ""
                delete head.trailer if head.trailer == ""
              resolve(head.etag = hash.digest("base64"))
          
          # saving to lookup and invalidation
          unless (newEntry = req.cacheObj)?
            (lookUp[req.url] ?= []).push newEntry = {}
            if req.dependencies?.length > 0
              watch req.dependencies, newEntry
          req.end.hookIn req.position.end, => 
            for k,v of save
              newEntry[k] = req[k]
            newEntry.body = req.body
            newEntry.statusCode = req.statusCode if req.statusCode > 304

module.exports.configSchema = require("./configSchema")