#!/bin/bash
cd /Users/sumitbagewadi/Documents/freezmeonflutter/freezme/ios
xcodebuild archive \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath /tmp/freezme.xcarchive \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGN_IDENTITY="iPhone Distribution" \
  DEVELOPMENT_TEAM=VGB523B9F6
