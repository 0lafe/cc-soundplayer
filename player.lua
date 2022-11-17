os.loadAPI("button.lua")
local monitor = peripheral.find('monitor')
local baseURL = ''
local lastSpeaker = ''
local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()
local speakers = {peripheral.find('speaker')}
local currentSong

local function downloadSong(id)
	local req = http.get {url = baseURL .. "/audio/" .. id, binary = true}
	local song = req.readAll()

	local file = fs.open('song.dfpwm', 'wb')
	file.write(song)
	file.close()
	req.close()
end

local function playSongTest()
	for chunk in io.lines("song.dfpwm", 16 * 1024) do
		local buffer = decoder(chunk)
		
		for i, v in ipairs(speakers) do
			v.playAudio(buffer)
		end
		
		local bool, speaker
		repeat
			bool, speaker = os.pullEvent("speaker_audio_empty")
		until speaker == lastSpeaker
	end
end

local function upload()
	print('Paste a youtube url of the song you wish to upload')
	local url = io.stdin._handle.readLine()
	
	local req = http.get {url = baseURL .. "/audio/new?url=" .. url}
	
	print('Processing. The song should appear in the song list soon')
end

local function parseJson(json)
	local v1 = 1
	local v11 = 1
	local outputI = 1
	local temp
	local item = {}
	local output = {}

	for i = 1, #json do
		local c = json:sub(i,i)
		if c == "{" then
			v1 = i
		elseif c == "}" then
			temp = json:sub(v1, i)
			for ii = 1, #temp do
				local c = temp:sub(ii,ii)
				if c == ":" then
					v11 = ii
				elseif c == "," then
					item['id'] = temp:sub(v11 + 1, ii - 1)
				elseif c == "}" then
					item['title'] = temp:sub(v11 + 2, ii - 2)
				end
			end
			output[outputI] = item
			outputI = outputI + 1
			item = {}
		end
	end

	return (output)
end

local function setCurrentSong(id)
	currentSong = id
end

local function createButtons(songs)
	os.loadAPI("button.lua")
	button.setMonitor(monitor)
	monitor.setBackgroundColor(colors.black)

	local buttons = {}

	local myButton = button.create('Upload a New Song')
	myButton.setPos(1,1)
	myButton.setColor(colors.red)
	local function click()
		upload()
	end
	myButton.onClick(click)
	buttons[1] = myButton
	
	for i, v in pairs(songs) do
		local myButton = button.create(v['title'])
		myButton.setPos(1,2 * i + 1)
		myButton.setColor(colors.red)
		local function click()
			downloadSong(v['id'])
			setCurrentSong(v['id'])
			playSongTest()
		end
		myButton.onClick(click)
		buttons[i + 1] = myButton
	end

	return(buttons)
end

local function getSongs()
	local request = http.get { url = baseURL .. '/audio' }
	return(parseJson(request.readAll()))
end

local function clearTerminal()
	term.clear()
	term.setCursorPos(1,1)
end

monitor.clear()
local buttons = createButtons(getSongs())
clearTerminal()
while true do
	button.await(buttons)
end
