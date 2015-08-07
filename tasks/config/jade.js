/**
 * Precompiles Underscore templates to a `.jst` file.
 *
 * ---------------------------------------------------------------
 *
 * (i.e. basically it takes HTML files and turns them into tiny little
 *  javascript functions that you pass data to and return HTML. This can
 *  speed up template rendering on the client, and reduce bandwidth usage.)
 *
 * For usage docs see:
 * 		https://github.com/gruntjs/grunt-contrib-jst
 *
 */

module.exports = function(grunt) {

	var templateFilesToInject = [
		'templates/**/*.html'
	];

	grunt.config.set('jade', {
		dev: {
			options: {
			},
      files: [{
        expand: true,
        cwd: 'assets/templates/',
        src: ['**/*.jade'],
        dest: 'dist/templates/',
        ext: '.html'
      },{
        expand: true,
        cwd: 'assets/html/',
        src: ['**/*.jade'],
        dest: 'dist/html/',
        ext: '.html'
      }]
		}
	});

	grunt.loadNpmTasks('grunt-contrib-jade');
};
