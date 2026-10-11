# R8 keep rules for the release build. Debug builds aren't shrunk, so a missing
# rule (reflection, serialization, JNI) only crashes release: /play smoke-tests
# a release build on the emulator before every upload.
