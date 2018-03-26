var gulp = require('gulp');
var gutil = require('gulp-util');
var debug = require('gulp-debug');
var del = require('del');
var merge = require('merge-stream');
var path = require('path');
var shell = require('shelljs');
var minimist = require('minimist');

var _buildRoot = path.join(__dirname, '_build');
var _packagesRoot = path.join(__dirname, '_packages');

gulp.task('default', ['build']);

gulp.task('build', ['clean'], function () {
    var extension = gulp.src(['README.md', 'LICENSE.txt', 'images/**/*', '!images/**/*.pdn', 'vss-extension.json'], { base: '.' })
        .pipe(debug({title: 'extension:'}))
        .pipe(gulp.dest(_buildRoot));
    var task = gulp.src('task/**/*', { base: '.' })
        .pipe(debug({title: 'task:'}))
        .pipe(gulp.dest(_buildRoot));
    
    return merge(extension, task);
});

gulp.task('clean', function() {
   return del([_buildRoot]);
});

gulp.task('package', ['build'], function() {
    var args = minimist(process.argv.slice(2), {})
    
    shell.exec('tfx extension create --root "' + _buildRoot + '" --output-path "' + _packagesRoot +'"')
});