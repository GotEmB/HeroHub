#!/usr/bin/env node

fs = require "fs"
cp = require "child_process"
verbose = process.argv.indexOf "-v" isnt -1

child = (prc, args, funs...) ->
	funOut = funErr = funExit = null
		funExit = funs[0]
	else if funs.length is 2
		funOut = funErr = funs[0]
		funExit = funs[1]
	else if funs.length is 3
		funOut = funs[0]
		funErr = funs[1]
		funExit = funs[2]
	cps = cp.spawn prc, args
	cps.stdout.on "data", (data) ->
		process.stdout.write data if verbose
		funOut data if funOut?
	cps.stderr.on "data", (data) ->
		process.stderr.write data if verbose
		funErr data if funErr?
 	cps.on "exit", funExit

main = ->	
	await fs.stat ".ssh/id_rsa", defer err, stats
	if not err? or err.code isnt "ENOENT"
		console.error "An RSA key already exists in '.ssh'"
		console.info "Exiting. Nothing done."
		return
	await fs.stat ".ssh", defer err, stats
	fs.mkdirSync ".ssh" if err? and err.code is "ENOENT"
	
	process.stdout.write "Generating RSA Key for HeroHub...#{if verbose then "\n" else ""}"
	await child "ssh-keygen", ["-f", ".ssh/id_rsa", "-N", "", "-C", "HeroHub"], defer exitcode
	console.info "Done"
	
	process.stdout.write "Uploading RSA Key to Heroku...#{if verbose then "\n" else ""}"
	await child "heroku", ["keys:add", ".ssh/id_rsa.pub"], defer exitcode
	console.info "Done"
	
	process.stdout.write "Creating Heroku App...#{if verbose then "\n" else ""}"
	stdoe = ""
	await child "heroku", ["apps:create"], ((data) -> stdoe += data), ((data) -> stdoe += data), defer exitcode
	url = stdoe.match(/^(http:\/\/)([^ ]+)\.([^ ]+)(\.com\/)/m)[0]
	console.info "Done"
	
	process.stdout.write "Pushing Deployer App to Heroku...#{if verbose then "\n" else ""}"
	stdoe = ""
	await child "git", ["push", "heroku", "HEAD"], ((data) -> stdoe += data), ((data) -> stdoe += data), defer exitcode
	if (stdoe.match /failed/i)?
		console.info "Failed"
		console.error stdoe
		return
	else
		console.info "Done"
	
	console.info "All processes completed successfully.\nYour deployer app identifier is '#{url[2]}' and is hosted at '#{url[0]}'."

do main