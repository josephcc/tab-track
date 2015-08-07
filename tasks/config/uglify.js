/**
 * Minify files with UglifyJS.
 *
 * ---------------------------------------------------------------
 *
 * Minifies client-side javascript `assets`.
 *
 * For usage docs see:
 * 		https://github.com/gruntjs/grunt-contrib-uglify
 *
 */
module.exports = function(grunt) {

	grunt.config.set('uglify', {
		build: { 
      files: [{ 
        expand: true,
        cwd: './dist/js',
        src: '**/*.js',
        dest: 'dist/js'
      }]
    }
	});

	grunt.loadNpmTasks('grunt-contrib-uglify');
};
