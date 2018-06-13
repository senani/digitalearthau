import atexit
import os
import shutil
import tempfile
from pathlib import Path

from digitalearthau.paths import _write_files_to_dir


def write_files(files_spec, containing_dir=None):
    """
    Convenience method for writing a tree of files to a temporary directory.

    (primarily indended for use in tests)

    Dict format is "filename": "text content"

    If content is another dict, it is created recursively in the same manner.

    write_files({'test.txt': 'contents of text file'})

    :param containing_dir: Optionally specify the directory to add the files to,
                           otherwise a temporary directory will be created.
    :type files_spec: dict
    :rtype: pathlib.Path
    :return: Created temporary directory path
    """
    if not containing_dir:
        containing_dir = Path(tempfile.mkdtemp(suffix='neotestrun'))

    _write_files_to_dir(containing_dir, files_spec)

    def remove_if_exists(path):
        if os.path.exists(path):
            shutil.rmtree(path)

    atexit.register(remove_if_exists, containing_dir)
    return containing_dir