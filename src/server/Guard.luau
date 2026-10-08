--!strict
-- Guard: per-player, per-remote token buckets. Every remote handler calls allow() first
-- and silently drops the request when it returns false.

local Players = game:GetService("Players")

type Bucket = { tokens: number, last: number }

local buckets: { [Player]: { [string]: Bucket } } = {}

local Guard = {}

function Guard.allow(player: Player, key: string, perSecond: number, burst: number): boolean
	local now = os.clock()
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local bucket = playerBuckets[key]
	if not bucket then
		bucket = { tokens = burst, last = now }
		playerBuckets[key] = bucket
	end
	bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.last) * perSecond)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

return Guard
