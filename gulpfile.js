'use strict';

var fs = require('fs');
var path = require('path');
var del = require('del');
var eslint = require('gulp-eslint');
var gulp = require('gulp');
var istanbul = require('gulp-istanbul');
var mocha = require('gulp-mocha');
var plumber = require('gulp-plumber');
var shell = require('shelljs');
var spawn = require('child_process').spawn;
var gutil = require('gulp-util');

var copyNodeModulesToTasks = function (done) {
  fs.readdirSync('src').forEach(function (file) {
    var filePath = path.join('dist', 'src', file);
    if (fs.statSync(filePath).isDirectory()) {
      try {
        if (fs.statSync(path.join(filePath, 'task.json')).isFile()) {
          shell.cp('-rf', 'dist/node_modules', filePath);
        }
      } catch (e) {
        /* swallow error: not a task directory */
      }
    }
  });
  done();
};

var executeCommand = function (cmd, dir, done) {
  gutil.log('Running command: ' + cmd);
  var pwd = shell.pwd();
  if (undefined !== dir) {
    gutil.log(' Working directory: ' + dir);
    shell.cd(dir);
  }
  shell.exec(cmd, {silent: true}, function (code, stdout, stderr) {
    gutil.log(' stdout: ' + stdout);
    if (code !== 0) {
      gutil.log('Command failed: ' + cmd + '\nManually execute to debug');
      gutil.log(' stderr: ' + stderr);
    }
    shell.cd(pwd);
    done();
  });
};

var createVsixPackage = function (done) {
  if (!shell.which('tfx')) {
    gutil.log('Packaging requires tfx cli. Please install with `npm install tfx-cli -g`.');
    done();
    return;
  }
  var packagingCmd = 'tfx extension create --manifest-globs vss-extension.json --root dist/src --output-path dist';
  executeCommand(packagingCmd, shell.pwd(), done);
};

var getNodeDependencies = function (done) {
  gutil.log('Copy package.json to dist directory');
  shell.mkdir('-p', 'dist/node_modules');
  shell.cp('-f', 'package.json', 'dist');

  gutil.log('Fetch node modules to package with tasks');
  var npmPath = shell.which('npm');
  var npmInstallCommand = '"' + npmPath + '" install --production';
  executeCommand(npmInstallCommand, 'dist', done);
};

// Tasks
gulp.task('clean', function (done) {
  del('dist').then(function () {
    done();
  });
});

gulp.task('lint', ['clean'], function () {
  return gulp.src('**/*.js')
    .pipe(eslint())
    .pipe(eslint.format())
    .pipe(eslint.failAfterError());
});

gulp.task('build', ['lint'], function () {
  return gulp.src('src/**/*', {base: '.'})
    .pipe(gulp.dest('dist'));
});

gulp.task('pre-test', ['build'], function () {
  return gulp.src('src/**/*.js')
    .pipe(istanbul({includeUntested: true}))
    .pipe(istanbul.hookRequire());
});

gulp.task('test', ['mocha-test']);

gulp.task('mocha-test', ['pre-test'], function (done) {
  var mochaErr;

  gulp.src('test/**/*.js')
    .pipe(plumber())
    .pipe(mocha({reporter: 'spec'}))
    .on('error', function (err) {
      mochaErr = err;
    })
    .pipe(istanbul.writeReports())
    .on('end', function () {
      done(mochaErr);
    });
});

gulp.task('pester-test', ['pre-test'], function (done) {
  // Runs powershell unit tests based on pester
  var pester = spawn('powershell.exe', ['-Command', 'Invoke-Pester -EnableExit -Path test'], {stdio: 'inherit'});
  pester.on('exit', function (code) {
    if (code === 0) {
      done();
    } else {
      done('Pester tests failed!');
    }
  });

  pester.on('error', function () {
    // We may be in a non-windows machine or powershell.exe is not in path. Skip pester tests.
    done();
  });
});

gulp.task('default', ['test']);

gulp.task('package', ['test'], function (done) {
  getNodeDependencies(function () {
    // TODO We need a per task dependency copy
    copyNodeModulesToTasks(function () {
      createVsixPackage(done);
    });
  });
});
