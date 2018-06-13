import atexit
import os
import tempfile
from pathlib import Path

import shutil


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


def _write_files_to_dir(directory_path, file_dict):
    """
    Convenience method for writing a tree of files to a given directory.

    (primarily indended for use in tests)

    :type directory_path: str
    :type file_dict: dict
    """
    for filename, contents in file_dict.items():
        path = os.path.join(directory_path, filename)
        if isinstance(contents, dict):
            os.mkdir(path)
            _write_files_to_dir(path, contents)
        else:
            with open(path, 'w') as f:
                if isinstance(contents, list):
                    f.writelines(contents)
                elif isinstance(contents, str):
                    f.write(contents)
                else:
                    raise Exception('Unexpected file contents: %s' % type(contents))
