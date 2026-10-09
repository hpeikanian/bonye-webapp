import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('deploy', Path(__file__).parents[1] / 'deploy_ftps.py')
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)

class FakeFTP:
    def __init__(self, fail=False): self.events = []; self.fail = fail
    def cwd(self, path): self.events.append(('cwd', path))
    def mkd(self, path): self.events.append(('mkdir', path))
    def storbinary(self, command, stream, blocksize):
        self.events.append(('store', command))
        if self.fail: raise OSError('interrupted')
        self.assert_bytes = stream.read()
    def rename(self, source, target): self.events.append(('rename', target))

class DeploymentTests(unittest.TestCase):
    def fixture(self, root):
        for name in ['assets/logo.png', 'downloads/bonYe-v0.2.3-6.apk',
                     'index.html', 'flutter_bootstrap.js', 'main.dart.js', 'sw.js',
                     'source-revision.json', 'android-update.json', '.htaccess']:
            path = root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(b'fixture')
    def test_assets_apk_before_shell_and_manifest_last(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); self.fixture(root)
            ftp = FakeFTP(); deploy.upload(ftp, deploy.inventory(root))
            names = [path for kind, path in ftp.events if kind == 'rename']
            self.assertLess(names.index('downloads/bonYe-v0.2.3-6.apk'), names.index('android-update.json'))
            self.assertLess(names.index('assets/logo.png'), names.index('main.dart.js'))
            self.assertLess(names.index('index.html'), names.index('sw.js'))
            self.assertEqual(names[-1], 'android-update.json')
            self.assertIn('.htaccess', names)
    def test_interrupted_upload_never_promotes_partial_file(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); self.fixture(root); ftp = FakeFTP(fail=True)
            with self.assertRaises(OSError): deploy.upload(ftp, deploy.inventory(root))
            self.assertFalse(any(kind == 'rename' for kind, _ in ftp.events))
    def test_reject_incomplete_and_symlink(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with self.assertRaises(ValueError): deploy.inventory(root)
            self.fixture(root); (root / 'linked').symlink_to(root / 'index.html')
            with self.assertRaises(ValueError): deploy.inventory(root)

if __name__ == '__main__': unittest.main()
