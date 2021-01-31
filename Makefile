

binDir:=/usr/local/bin
shimPath:=${binDir}/vars


define shim
#!/bin/bash
export VARS_PATH=${CURDIR}
. $$VARS_PATH/vars.sh $$@

endef


install: 
	@$(file >${shimPath},$(shim))
	@chmod +x ${shimPath}
  $(info installed shim to ${shimPath})


