/**
 * Copy files and folders.
 *
 * ---------------------------------------------------------------
 *
 * # dev task config
 * Copies all directories and files, exept coffescript and less fiels, from the sails
 * assets folder into the .tmp/public directory.
 *
 * # build task config
 * Copies all directories nd files from the .tmp/public directory into a www directory.
 *
 * For usage docs see:
 * 		https://github.com/gruntjs/grunt-contrib-copy
 */
module.exports = function(grunt) {

	grunt.config.set('copy', {
		dev: {
			files: [{
				expand: true,
				cwd: './assets',
				src: ['**/*.!(jade|sass|scss)'],
				dest: 'dist/'
			}, {
        expand: true,
        cwd: './vendor',
        src: ['**/*.!(coffee|jade|scss|sass)'],
        dest: 'dist/vendor/'
      },{
        expand: true,
        cwd: './server/node_modules/socket.io/node_modules/socket.io-client',
        src: 'socket.io.js',
        dest: 'dist/vendor/socket.io/'
      }]
		},
		build: {
			files: [{
				expand: true,
				cwd: './assets',
				src: ['**/*.!(coffee|jade|sass|scss)'],
				dest: 'dist/'
			}, {
        expand: true,
        cwd: './vendor',
        src: ['**/*.!(coffee|jade|scss|sass)'],
        dest: 'dist/vendor/'
      },{
        expand: true,
        cwd: './server/node_modules/socket.io/node_modules/socket.io-client',
        src: 'socket.io.js',
        dest: 'dist/vendor/socket.io/'
      }]		
    }
	});

	grunt.loadNpmTasks('grunt-contrib-copy');
};
