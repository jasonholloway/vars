#!/bin/bash

[[ $__LIB_CHECK ]] || source lib/check.sh 
[[ $__LIB_VN ]] || source lib/vn.sh 

check "vn roundtrip" <<-'EOF'
    vn_read vn "v:dog{breed=pug}"
    parp vn_write vn
  .>
    dog{breed=pug}
EOF

check "vn, get name" <<-'EOF'
    vn_read vn "v:dog{breed=pug}"
    parp vn_getName vn
  .>
    dog
EOF

check "vn, get pins" <<-'EOF'
    declare -A pins
    vn_read vn "v:dog{breed=pug+hair=long}"
    vn_getPins vn pins
  .,
    chk pins[breed] eq pug
    chk pins[hair] eq long
EOF

check "vn, set pins" <<-'EOF'
    vn_read vn "v:dog{breed=pug+hair=long}"

    declare -A pins
    vn_getPins vn pins
    pins[breed]=doberman
    pins[legs]=4
    vn_setPins vn pins

    parp vn_write vn
  .>
    dog{breed=doberman+hair=long+legs=4}
EOF

check "vn, no pins no brackets" <<-'EOF'
    vn_read vn "v:dog{breed=pug}"

    declare -A pins
    vn_setPins vn pins

    parp vn_write vn
  .>
    dog
EOF
