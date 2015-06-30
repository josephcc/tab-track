
header2csv = (attributes) ->
  return '"' + attributes.join('","') + '"' + '\n'

object2csv = (object, attributes) ->
  row = []
  for attribute in attributes
    row.push ("" + object[attribute]).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
  return '"' + row.join('","') + '"' + '\n'

errorHandler = (e) ->
  msg = ''

  switch (e.code)
    when FileError.QUOTA_EXCEEDED_ERR
      msg = 'QUOTA_EXCEEDED_ERR'
    when FileError.NOT_FOUND_ERR
      msg = 'NOT_FOUND_ERR'
    when FileError.SECURITY_ERR
      msg = 'SECURITY_ERR'
    when FileError.INVALID_MODIFICATION_ERR
      msg = 'INVALID_MODIFICATION_ERR'
    when FileError.INVALID_STATE_ERR
      msg = 'INVALID_STATE_ERR'
    else
      msg = 'Unknown Error'

  console.log('Error: ' + msg)
