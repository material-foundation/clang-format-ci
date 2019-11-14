# 1.2.1

This patch release uses a more explicit invocation to calculate the sha of the clang-format
binaries. The readme has also been updated to include a more generalizable installation method.

The invocation `openssl sha` appears to have been removed from recent continuous integration
machines. This release now uses a more explicit `openssl sha256` invocation.

# 1.2.0

This minor release updates clang-format to r352957.

# 1.1.0

This minor release updates clang-format to r351607, includes some minor cleanup to the scripts, and
removes the need to initialize submodules when cloning the repository.

# 1.0.0

This is the initial stable release of clang-format-ci. It includes support for running clang-format
from Travis CI and Kokoro jobs. This release has solely been tested on Mac platforms thus far, but
it may also support other platforms.


