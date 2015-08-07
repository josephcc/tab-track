/**
 * Compiles SASS files into CSS.
 *
 * ---------------------------------------------------------------
 *
 * Only the `assets/styles/importer.sass` is compiled.
 * This allows you to control the ordering yourself, i.e. import your
 * dependencies, mixins, variables, resets, etc. before other stylesheets)
 *
 * For usage docs see:
 * 		https://github.com/gruntjs/grunt-contrib-sass
 */
module.exports = function(grunt) {

	grunt.config.set('sass', {
      dev: {
        options: {
          style: 'nested'
        },
        files: [{
          expand: true,
          cwd: 'assets/css/',
          src: ['*.scss', '*.sass'],
          dest: 'dist/css/',
          ext: '.css'
        }]
      },
     build: {
        options: {
          style: 'compressed',
          sourcemap: 'none'
        },
        files: [{
          expand: true,
          cwd: 'assets/css/',
          src: ['*.scss', '*.sass'],
          dest: 'dist/css/',
          ext: '.css'
        }]
      }
	});

	grunt.loadNpmTasks('grunt-sass');
};
