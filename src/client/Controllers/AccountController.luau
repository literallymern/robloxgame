--!strict
-- "Account" window: link status, "Link Discord", balances and recent transactions, all read from
-- the economy bot through the server. The client never decides anything about money.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyTypes = require(ReplicatedStorage.Shared.Types.Economy)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Ui = require(script.Parent.Parent.Util.Ui)
local NotificationController = require(script.Parent.NotificationController)
local UIController = require(script.Parent.UIController)

type Reply = EconomyTypes.Reply

local AccountController = {}

local window: Frame
local statusLabel: TextLabel
local balanceLabel: TextLabel
local codeLabel: TextLabel
local historyLabel: TextLabel
local linkButton: TextButton
local refreshButton: TextButton
local testRow: Frame
local busy = false

local function invoke(name: string, ...: any): Reply
	local remote = Remotes.getFunction(name)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if not ok or type(result) ~= "table" then
		return { ok = false, error = "network", message = "No answer from the server. Please try again." }
	end
	return result :: Reply
end

local function sign(direction: string): string
	return if direction == "in" then "+" else "-"
end

local function showHistory()
	local reply = invoke(Remotes.Functions.GetTransactions, "bank", 1)
	if not reply.ok or type(reply.data) ~= "table" then
		historyLabel.Text = ""
		return
	end
	local lines = { "Recent bank transactions:" }
	for index, item in reply.data.items do
		if index > 5 then
			break
		end
		table.insert(lines, `{sign(item.direction)}{Format.kgd(item.amount)}  ·  {item.category}  ·  day {item.day}`)
	end
	if #lines == 1 then
		table.insert(lines, "none yet")
	end
	historyLabel.Text = table.concat(lines, "\n")
end

local function render(reply: Reply)
	local view = reply.data
	codeLabel.Visible = false
	historyLabel.Text = ""
	testRow.Visible = false
	linkButton.Visible = false
	balanceLabel.Text = ""

	if type(view) ~= "table" then
		statusLabel.Text = reply.message or "No data."
		return
	end
	if not view.linked then
		if not reply.ok then
			statusLabel.Text = reply.message or "Financial services are temporarily unavailable."
			return
		end
		statusLabel.Text = "Your Roblox account is not linked to Discord yet. Linking connects you to your "
			.. "Kagundi bank account in the Ro-Nation economy bot on Discord."
		linkButton.Visible = true
		return
	end

	local lines = { `Linked to Discord: {view.displayName or "member"}` }
	if view.maintenance then
		table.insert(lines, "The economy is in maintenance mode: you can look, but not change anything.")
	end
	if view.frozen then
		table.insert(lines, "Your accounts are frozen. Please contact the economic administration in Discord.")
	end
	if view.removalEffectiveAt then
		table.insert(lines, `This link ends at {Format.localTime(view.removalEffectiveAt)} (requested in Discord).`)
	end
	statusLabel.Text = table.concat(lines, "\n")

	if view.bank ~= nil then
		balanceLabel.Text = `Bank: {Format.kgd(view.bank)}\nCash: {Format.kgd(view.cash or 0)}\n`
			.. `Credit score: {view.creditScore or "-"}\nAs of {Format.localTime(view.asOf)} (from the economy bot)`
	else
		balanceLabel.Text = "No Kagundi bank account yet. Open one in Discord with /bank balance."
	end
	testRow.Visible = view.canRunTests == true
	showHistory()
end

local function refresh()
	if busy then
		return
	end
	busy = true
	statusLabel.Text = "Loading..."
	render(invoke(Remotes.Functions.GetAccount))
	busy = false
end

local function requestCode()
	if busy then
		return
	end
	busy = true
	local reply = invoke(Remotes.Functions.RequestLinkCode)
	busy = false
	if not reply.ok or type(reply.data) ~= "table" then
		NotificationController.show(reply.message or "Could not get a code.", "error")
		return
	end
	if reply.data.linked then
		refresh()
		return
	end
	codeLabel.Text = `Your code: {reply.data.code}\n\nIn Discord, type:\n/link confirm code:{reply.data.code}\n\n`
		.. `The code works once, until {Format.localTime(reply.data.expiresAt)}. Then press Refresh.`
	codeLabel.Visible = true
end

local function testTransfer(direction: "withdraw" | "deposit")
	if busy then
		return
	end
	busy = true
	NotificationController.show("Sending test transfer...", "info")
	local reply = invoke(Remotes.Functions.RunTestTransfer, direction)
	busy = false
	NotificationController.show(
		reply.message or (if reply.ok then "Done." else "Not carried out."),
		if reply.ok then "success" else "error"
	)
	refresh()
end

local function build()
	window = Instance.new("Frame")
	window.Name = "AccountWindow"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.new(0.5, 0, 0.5, 0)
	window.Size = UDim2.new(0, 400, 0, 0)
	window.AutomaticSize = Enum.AutomaticSize.Y
	window.BackgroundColor3 = Ui.Colors.Background
	window.Visible = false
	Ui.corner(window, 10)
	Ui.padding(window, 16)
	Ui.list(window, 10)

	local title = Ui.label(window, 1, "Kagundi Bank Account", 20)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Ui.Colors.Accent

	statusLabel = Ui.label(window, 2, "")
	balanceLabel = Ui.label(window, 3, "", 18)
	codeLabel = Ui.label(window, 4, "", 18)
	codeLabel.Font = Enum.Font.GothamMedium
	codeLabel.Visible = false

	local buttons = Ui.row(window, 5)
	linkButton = Ui.button(buttons, 1, "Link Discord")
	refreshButton = Ui.button(buttons, 2, "Refresh", Ui.Colors.Panel)
	local closeButton = Ui.button(buttons, 3, "Close", Ui.Colors.Panel)

	testRow = Ui.row(window, 6)
	local withdraw = Ui.button(testRow, 1, "Test: withdraw 1 KGD", Ui.Colors.Info)
	local deposit = Ui.button(testRow, 2, "Test: deposit 1 KGD", Ui.Colors.Info)
	testRow.Visible = false

	historyLabel = Ui.label(window, 7, "", 14)
	historyLabel.TextColor3 = Ui.Colors.Muted

	linkButton.Activated:Connect(requestCode)
	refreshButton.Activated:Connect(refresh)
	closeButton.Activated:Connect(function()
		window.Visible = false
	end)
	withdraw.Activated:Connect(function()
		testTransfer("withdraw")
	end)
	deposit.Activated:Connect(function()
		testTransfer("deposit")
	end)

	window.Parent = UIController.getScreen()
end

function AccountController.start()
	build()
	UIController.addMenuButton("Account").Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			refresh()
		end
	end)
end

return AccountController
