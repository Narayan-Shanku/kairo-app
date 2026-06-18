"""Test setup — isolate Kairō storage to a throwaway directory.

KAIRO_HOME must be set *before* backend.config is imported, since config builds
its paths at import time. Doing it here (conftest is imported first) keeps real
user data in ~/.kairo untouched.
"""

import os
import tempfile

os.environ["KAIRO_HOME"] = tempfile.mkdtemp(prefix="kairo-test-")
