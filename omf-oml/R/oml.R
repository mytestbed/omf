library('R.methodsS3')
library('R.oo')
library('XML')
library('RCurl')

setConstructorS3("OML", function(omlHost = NA, serviceName = 'result2') {
  
  extend(Object(), "OML",
    omlHost = omlHost,
    url = paste('http://', omlHost, '/', serviceName, sep = '')
  );
})

setMethodS3("repo", "OML", function(this, repoName) {
  OmlRepository(repoName, this)
})

######## REPOSITORY

setConstructorS3("OmlRepository", function(repoName = NA, oml = NA) {

  extend(Object(), "OmlRepository",
    .repoName = repoName,
    .oml = oml
  );
})

setMethodS3("table", "OmlRepository", function(this, name) {
  OmlTable(name, NA, this)
})

setMethodS3("serviceURI", "OmlRepository", function(this) {
  paste(this$.oml$url, '/query', sep = '')
})

setMethodS3("toXML", "OmlRepository", function(this) {
  n <- newXMLNode("query"
#                  namespace = "r",
#                  namespaceDefinitions = c("r" = "http://www.fo.org")),
                  )
  newXMLNode("repository",
             attrs = c(name = this$.repoName),
             parent = n)
  n
})

######## RELATION

setConstructorS3("OmlRelation", function(relName = NA, args = NA, prevRel = NA) {
#  print(paste('XXX', typeof(args)))
#  print(paste("NEWR:", relName, args, prevRel))
  extend(Object(), "OmlRelation",
    .relName = relName,
    .args = args,
    .prevRel = prevRel
  );
})

for (r in c('from', 'group', 'having', 'join', 'order', 'on',
            'project', 'where', 'skip', 'take', 'lock')) {
  c <- paste('setMethodS3("', r, '", "OmlRelation", function(this, ...) {',
             'args <- list(...);',
#             'print(paste("NEW REL:", typeof(args)));',
             'OmlRelation("', r, '", args, this);',
             '})', sep = '')
  eval(parse(text = c))
}

setMethodS3("toXML", "OmlRelation", function(this, pel = NA) {
  prev <- this$.prevRel
#  print(paste('--> OmlRelation::toXML', this$.relName, prev, is.null(prev)))
  if (!is.null(prev)) {
#     print('---> next')
     pel <- prev$toXML(pel)
  }
  if (is.null(pel)) {
     throw(paste("Can't find proper head of relation:", this$.relName))
  }
  n <- newXMLNode(this$.relName, parent = pel)
#  print(paste('--> OmlRelation::toXML::args', typeof(this$.args)))
  for (a in this$.args) {
    an <- newXMLNode('arg', parent = n)
    if (is.object(a)) {
      a$toXML(an)
    } else {
    }
  }
  pel
})

setMethodS3("data", "OmlRelation", function(this, pel = NA) {
  q <- this$toXML()
  id <- this$hashCode()
  r <- newXMLNode('request',
             attrs = c(id = this$hashCode()),
             namespaceDefinitions = 'http://schema.mytestbed.net/am/result/2/'
             )
  res <- newXMLNode('result', parent = r)
  newXMLNode('format', 'CSV',
             attrs = c(type = 'CSV', delim=';', header = 'true'),
             parent = res)  
  addChildren(r, q)

#  # prepare service request

  url = this$.getRepo()$serviceURI()
  handle = getCurlHandle()
  header = c(Accept = "text/xml", 'Content-Type' = "text/xml; charset=utf-8")
  readerF= basicTextGatherer()
  headerF = basicTextGatherer()
  body = saveXML(r)
  
  curlPerform(url = url,
              httpheader = header,
              postfields = body,
              writefunction = readerF$update,
              headerfunction = headerF$update,
              curl = handle
              )
  status = getCurlInfo(handle)$response.code
  if (status != 200) {
    throw(paste("OML::Web::", status, ": ", readerF$value(), sep = ''))
  }
  rh = parseHTTPHeader(headerF$value())
  ct = rh[['Content-Type']]
  if (ct == 'text/csv') {
    this$.parseCSV(readerF$value())
  } else {
    throw(paste("OML::Format: Unrecognised reply format '", ct, '".', sep = ''))
  }
})

setMethodS3(".parseCSV", "OmlRelation", function(this, res) {
  b = strsplit(res, '\n')[[1]] # split returned text into vector of lines
  #  first line>>  #  foo:string goo:double
  h = strsplit(b[1], ' ')[[1]][-1] # [-1] splits off '#'
  names = lapply(h, function(x) {strsplit(x, ':')[[1]][1]})
  types = lapply(h, function(x) {
    t = strsplit(x, ':')[[1]][2]
    if (t == 'double' || t == 'integer') {
      t
    } else if (t == 'text' || t == 'string') {
      'character'
    } else {
      throw(paste("Unknown SQL type '", t, '".', sep = ''))
    }
  })
  body = textConnection(b[-1])
  t = read.table(body, header=FALSE, sep=';', col.names = names, colClasses = types)
  close(body)  # close connection, otherwise we see warning on timeout
  t
})

setMethodS3(".getRepo", "OmlRelation", function(this) {
  prev <- this$.prevRel
#    print(prev)
  if (is.object(prev)) {
#    print(prev)
    return(prev$.getRepo())
  }
  throw("Can't find repo on this relation chain")
})


############ TABLE

setConstructorS3("OmlTable", function(tableName = NA, tableAlias = NA, repo = NA) {

  extend(OmlRelation('table'), "OmlTable",
    tableName = tableName,
    tableAlias = tableAlias,
    .repo = repo
  );
})

setMethodS3("as", "OmlTable", function(this, alias) {
  OmlTable(this$tableName, alias, this$.repo)
})

setMethodS3("[", "OmlTable", function(this, name) {
  OmlColumn(name, NA, this)
})

setMethodS3("toXML", "OmlTable", function(this, pel = NA) {
  #pel <- toXML.OmlRelation(this, pel, FALSE);
  if (is.na(pel)) {
    #print(paste("....", pel, this$.repo))
    pel <- this$.repo$toXML()
  }
  n <- newXMLNode("table",
             attrs = c(tname = this$tableName),
             parent = pel)
  
  if (!is.na(a <- this$tableAlias)) {
    addAttributes(n, talias = a)
  }
  pel
})

setMethodS3(".getRepo", "OmlTable", function(this) {
  this$.repo
})

###### PREDICATE

setConstructorS3("OmlPredicate", function(predName = NA, args = NA, prev = NA) {
  #throw('Not implemented, yet')

  extend(Object(), "OmlPredicate",
    .predName = predName,
    .args = args,
    .prev = prev
  );
})

for (p in c('eq', 'eq_any', 'eq_all', 'not_eq', 'not_eq_any', 'not_eq_all', 'lt', 'lt_any',
            'lt_all', 'lteq', 'lteq_any', 'lteq_all', 'gt', 'gt_any', 'gt_all', 'gteq',
            'gteq_any', 'gteq_all', 'matches', 'matches_any', 'matches_all', 'not_matches',
            'not_matches_any', 'not_matches_all',
            #'in',
            'in_any', 'in_all', 'not_in',
            'not_in_any', 'not_in_all')) {
  c <- paste('setMethodS3("', p, '", "OmlPredicate", function(this, ...) {',
             'OmlPredicate("', p, '", list(...), this)})', sep = '')
  eval(parse(text = c))
}

setMethodS3("toXML", "OmlPredicate", function(this, pel = NA) {
  prev <- this$.prev
  print(paste('--> OmlPredicae::toXML', this$.predName, prev, is.null(prev)))
  if (!is.null(prev)) {
     print('---> next')
     prev$toXML(pel)
  }
  if (is.null(pel)) {
     throw(paste("Can't find proper head of predicate:", this$.predName))
  }
  n <- newXMLNode(this$.predName, parent = pel)
  print(paste('--> OmlPredicate::toXML::args', typeof(this$.args)))
  for (a in this$.args) {
    an <- newXMLNode('arg', parent = n)
    if (is.object(a)) {
      a$toXML(an)
    } else {
      addAttributes(an, type = typeof(a))
      newXMLTextNode(a, parent = an)
    }
  }
  pel
})
            
######## COLUMN

setConstructorS3("OmlColumn", function(colName = NA, colAlias = NA, table = NA) {

  extend(OmlPredicate('col'), "OmlColumn",
    .colName = colName,
    .colAlias = colAlias,
    .table = table
  );
})

setMethodS3("as", "OmlColumn", function(this, alias) {
  OmlColumn(this$.colName, alias, this$.table)
})

setMethodS3("toXML", "OmlColumn", function(this, pel = NA) {
  n <- newXMLNode('col', parent = pel)
  addAttributes(n, name = this$.colName)
  alias = this$.colAlias
  if(!is.na(alias)) {
    addAttributes(n, alias = alias)
  }
  
  addAttributes(n, table = this$.table$tableName)
  talias <- this$.table$tableAlias
  if(!is.na(talias)) {
    addAttributes(n, talias = talias)
  }
})
