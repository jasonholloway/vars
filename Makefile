.PHONY: fzy

binDir:=/usr/local/bin
shimPath:=${binDir}/vars


define shim
#!/bin/bash
export VARS_PATH=${CURDIR}
. $$VARS_PATH/vars.sh $$@

endef

install: canRead fzy ptyize pause
	@$(file >${shimPath},$(shim))
	@chmod +x ${shimPath}
	$(info installed shim to ${shimPath})

canRead: canRead.c

fzy: 
	cd fzy && make

ptyize: ptyize.c

pause: pause.c

