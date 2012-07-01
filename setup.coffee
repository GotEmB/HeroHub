#!/usr/bin/env node

main = ->
	fs = require "fs"
	cp = require "child_process"
	
	await fs.stat ".ssh/id_rsa", defer err, stats
	if not err? or err.code isnt "ENOENT"
		console.error "An RSA key already exists in '.ssh'"
		console.info "Exiting. Nothing done."
		return
	await fs.stat ".ssh", defer err, stats
	fs.mkdirSync ".ssh" if err? and err.code is "ENOENT"
	
	process.stdout.write "Generating RSA Key for HeroHub..."
	cps = cp.spawn "ssh-keygen", ["-f", ".ssh/keygen", "-N", "\"\"", "-C", "HeroHub"]
	await cps.exit.on defer exitcode
	console.info "Done"
	
	process.stdout.write "Uploading RSA Key to Heroku..."
	cps = cp.spawn "heroku", ["keys:add", ".ssh/id_rsa.pub"]
	await cps.exit.on defer exitcode
	console.info "Done"
	
	process.stdout.write "Creating Heroku App..."
	cps = cp.spawn "heroku", ["apps:create"]
	stdoe = ""
	cps.stdout.on (data) -> stdoe += data
	cps.stderr.on (data) -> stdoe += data
	await cps.exit.on defer exitcode
	url = stdoe.match(/^(http:\/\/)([^ ]+)\.([^ ]+)(\.com\/)/m)[0]
	console.info "Done"
	
	process.stdout.write "Pushing Deployer App to Heroku..."
	cps = cp.spawn "git", ["push", "heroku"]
	stdoe = ""
	cps.stdout.on (data) -> stdoe += data
	cps.stderr.on (data) -> stdoe += data
	await cps.exit.on defer exitcode
	if (stdoe.match /failed/i)?
		console.info "Failed"
		console.error stdoe
		return
	else
		console.info "Done"
	
	console.info "All processes completed successfully.\nYour deployer app identifier is '#{url[2]}' and is hosted at '#{url[0]}'."

do main