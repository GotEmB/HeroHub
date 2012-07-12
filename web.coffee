# Load Modules
express	= require "express"
fs		= require "fs"
fluent	= require "./fluent"
request	= require "request"
md5		= require "MD5"
moment	= require "moment"
child_p	= require "child_process"

# Helper Methods
String::getHashtags = -> @match(/(#[A-Za-z0-9-_]+)/g).select (x) -> x.replace /#/, ""

log = (message) -> console.log message

cloneRepo = (repo, folder, callback) ->
	stderr = ""
	git = child_p.spawn "git", ["clone", repo, folder]
	git.stdout.on "data", (data) -> stderr += data
	git.stderr.on "data", (data) -> stderr += data
	await git.on "exit", defer exitcode
	if stderr.indexOf("fatal") isnt -1
		callback
			success:	false
			message:	stderr
			code:		1
	else
		callback
			success:	true

pushRepo = (repo, folder, commit, callback) ->
	stderr = ""
	git = child_p.spawn "git", ["add", "."], cwd: folder
	git.stdout.on "data", (data) -> stderr += data
	git.stderr.on "data", (data) -> stderr += data
	await git.on "exit", defer exitcode
	git = child_p.spawn "git", ["commit", "-m", "Building commit #{commit}."], cwd: folder
	git.stdout.on "data", (data) -> stderr += data
	git.stderr.on "data", (data) -> stderr += data
	await git.on "exit", defer exitcode
	git = child_p.spawn "git", ["push", "origin", "HEAD"], cwd: folder
	git.stdout.on "data", (data) -> stderr += data
	git.stderr.on "data", (data) -> stderr += data
	await git.on "exit", defer exitcode
	if stderr.indexOf("fatal") isnt -1
		callback
			success:	false
			message:	stderr
			code:		2
	else
		callback
			success:	true

getAppGit = (app, provider) -> "git@#{provider}.com:#{app}.git"

parseDeployString = (deployString) ->
	(do deployString.lines).select (line) ->
		a = line.split(":").select (x) -> do x.words
		app:
			name:		a[0][1]
			provider:	a[0][0]
		trigger:
			type:		a[1][0]
			target:		a[1][1]

updateFolderFromGitHub = (ghPath, commit, folder, callback) ->
	recSrc = (treeUrl, folder, callback) ->
		await request treeUrl, defer err, res, body
		tree = JSON.parse(body).tree
		ffn = (node, callback) ->
			if node.type is "tree"
				nf = "#{folder}/#{node.path}"
				await fs.mkdir nf, "0777", defer err
				await recSrc node.url, nf, defer done
			else if node.type is "blob"
				await request node.url, defer err, res, body
				blob = JSON.parse body
				await fs.writeFile "#{folder}/#{node.path}", new Buffer(blob.content, blob.encoding), defer err
			callback null
		await for nd in tree
			ffn nd, defer done
		callback null
	await recSrc "#{ghPath}/git/trees/#{commit.id}", folder, defer done
	callback null

doItGitHub = (ghPath, commit, targetApp, targetProvider, callback) ->	
	folder = "sandbox/" + md5 "#{ghPath}/#{commit} -> #{targetApp}@#{targetProvider}, #{do (new Date).getTime}"
	targetRepo = getAppGit targetApp, targetProvider
	await cloneRepo targetRepo, folder, defer cR
	callback cR unless cR.success
	await updateFolderFromGitHub ghPath, commit, folder, defer uR
	await pushRepo targetRepo, folder, commit, defer pR
	callback pR

processGitHub = (payload) ->
	return "Private repositories are currently not supported." if payload.repository.private
	ghPath = "https://api.github.com/repos/#{payload.repository.owner.name}/#{payload.repository.name}"
	payload.commits = payload.commits.orderByDesc (x) -> moment x.timestamp
	doneTriggers =
		branches: []
		hashtags: []
	payload.commits.forEach (commit) ->
		await request "#{ghPath}/git/trees/#{commit.id}", defer err, res, body
		rootTree = JSON.parse(body).tree
		unless rootTree.any((x) -> x.path is ".deploy")
			ret += "#{commit.id}: Could not find file `.deploy`.\n"
			return
		await request "#{ghPath}/git/blobs/#{rootTree.first((x) -> x.path is ".deploy").sha}", defer err, res, body
		deployFile = parseDeployString new Buffer(JSON.parse(body).content, JSON.parse(body).encoding).toString "utf-8"
		await request "#{ghPath}/branches", defer err, res, body
		branches = JSON.parse body
		deployFile.forEach (target) ->
			if do target.app.provider.toLowerCase isnt "heroku"
				log "#{payload.repository.name}:#{commit.id}/.deploy: #{target.app.provider} targets are not supported.\n"
				return
			runDoIt = (callback) ->
				await doItGitHub ghPath, commit, target.app.name, target.app.provider, defer dTS
				log "#{payload.repository.name}:#{commit.id} -> #{target.app.name}"
				log if dTS.success then "> Completed" else "> Failed (#{dTS.code})\n#{dTS.message}"
				callback dTS.success
			if do target.trigger.type.toLowerCase is "branch"
				if branches.any ((x) -> x.name is target.trigger.target and x.commit.sha is commit.id and not doneTriggers.branches.contains x.name)
					await runDoIt defer ran
					doneTriggers.branches.push target.trigger.target if ran
			else if do target.trigger.type.toLowerCase is "hashtag"
				if (do commit.message.getHashtags).except(doneTriggers.hashtags).contains target.trigger.target
					await runDoIt defer ran
					doneTriggers.hashtags.push target.trigger.target if ran

# Setup Server
server = do express.createServer
server.configure ->
	server.use do express.logger
	server.use do express.bodyParser

# POST Request - GitHub
server.post "/deploy/github", (req, res, next) ->
	processGitHub JSON.parse req.body.payload
	do res.send

# Start Server
server.listen (port = process.env.PORT || 6276), -> console.log "Listening on #{port}"