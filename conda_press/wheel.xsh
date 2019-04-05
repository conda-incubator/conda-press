"""Tools for representing wheels in-memory"""
import base64
from hashlib import sha256
from zipfile import ZipFile

from conda_press import __version__ as VERSION


def urlsafe_b64encode_nopad(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=')


def urlsafe_b64decode_nopad(data):
    pad = b'=' * (4 - (len(data) & 3))
    return base64.urlsafe_b64decode(data + pad)


def record_hash(data):
    dig = sha256(data).digest()
    b64 = urlsafe_b64encode_nopad(dig)
    return 'sha256=' + b64.decode('utf8')


class Wheel:
    """A wheel representation that knows how to write itself out."""

    def __init__(self, distribution, version, build_tag=None, python_tag='py3',
                 abi_tag='none', platform_tag='any'):
        """
        Parameters
        ----------
        distribution : str
            The 'distribution name', or the package name, e.g. "numpy"
        version : str
            The version string for the package
        build_tag : str or int, optional
            The build number, must start with a digit, See PEP #427
        python_tag : str, optional
            The Python version tag, see PEP #425
        abi_tag : str, optional
            The Python ABI tag, see PEP #425
        platform_tag : str, optional
            The platform tag, see PEP #425

        Attributes
        ----------
        noarch_python : bool
            Whether the package is a 'noarch: python' conda package.
        """
        self.distribution = distribution
        self.version = version
        self.build_tag = build_tag
        self.python_tag = python_tag
        self.abi_tag = abi_tag
        self.platform_tag = platform_tag
        self.noarch_python = False
        self._records = [(f"{distribution}-{version}.dist-info/RECORD", "", "")]

    def __repr__(self):
        return f'{self.__class__.__name__}({self.filename})'

    @property
    def filename(self):
        parts = [self.distribution, self.version]
        if self.build_tag is not None:
            parts.append(self.build_tag)
        parts.extend([self.python_tag, self.abi_tag, self.platform_tag])
        return '-'.join(parts) + '.whl'

    @property
    def compatibility_tag(self):
        return "-".join([self.python_tag, self.abi_tag, self.platform_tag])

    def write(self):
        with ZipFile(self.filename, 'w') as zf:
            self.zf = zf
            self.write_wheel_metadata(zf)
            del self.zf

    def _writestr_and_record(self, arcname, data):
        if isinstance(data, str):
            data = data.encode('utf-8')
        self.zf.writestr(arcname, data)
        record = (arcname, record_hash(data), len(data))
        self._records.append(record)

    def write_metadata(self, zf):
        lines = ["Metadata-Version: 2.1", "Name: " + self.distribution,
                 "Version: " + self.version]
        content = "\n".join(lines)
        arcname = f"{self.distribution}-{self.version}.dist-info/METADATA"
        self._writestr_and_record(arcname, content)

    def write_wheel_metadata(self, zf):
        lines = ["Wheel-Version: 1.0", "Generator: conda-press " + VERSION]
        lines.append("Root-Is-Purelib: " + str(self.noarch_python).lower())
        lines.append("Tag: " + self.compatibility_tag)
        if self.build_tag is not None:
            lines.append("Build: " + self.build_tag)
        content = "\n".join(lines)
        arcname = f"{self.distribution}-{self.version}.dist-info/WHEEL"
        self._writestr_and_record(arcname, content)
