import json, hashes, strutils

type
  MessageType* = enum
    TextMessage, ServiceMessage, ConnectionMessage,
    WarningMessage, ErrorMessage

  Message* = object
    username*: string
    mtype*: MessageType
    text*: string
    hash*: int

proc getHash*(username, text: string): int =
  return hash(username & text)

proc getHash*(message: Message): int =
  return hash(message.username & message.text)

proc verifyMessage*(message: Message): bool =
  return getHash(message) == message.hash

proc parseMessage*(data: string): Message =
  let dataJson = parseJson(data)
  result.username = dataJson["username"].getStr()
  result.text = dataJson["text"].getStr()
  result.mtype = parseEnum[MessageType](dataJson["mtype"].getStr())
  result.hash = dataJson["hash"].getInt()

proc createMessage*(username, text: string; mtype: MessageType): string =
  result = $(%{
    "username": %username,
    "text": %text,
    "mtype": %mtype,
    "hash": %getHash(username, text)
  }) & "\c\l"


when isMainModule:
  let hash = getHash("John" & "Hi!")
  let data = """{"username": "John", "text": "Hi!", "hash": 6635146331310275049, "mtype": 0}"""

  let parsed = parseMessage(data)
  doAssert parsed.username == "John"
  doAssert parsed.text == "Hi!"
  doAssert parsed.hash == getHash("John" & "Hi!")
  echo "All tests passed"
