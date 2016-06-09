do

function run(msg, matches)
  return [[ s p o l BoT
  
 Version: 2.2
  
  more information
  send 
  !s p o l bot to chat
  Developer and manager is 
  @crazyboy10
  TNX to all]]
end

return {
  description = "Shows bot version", 
  usage = "!version: Shows bot version",
  patterns = {
    "^[!/]version$",
    "^[!/]ver$",
    "^[Vv]ersion$",
    "^[Vv]er$"
  }, 
  run = run 
}

end
