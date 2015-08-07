/**
 * Creates a ctx file for the extension 
 *
 * ---------------------------------------------------------------
 *
 * grunt-crx is a Grunt task used to package Chrome Extensions. 
 *
 * For usage docs see:
 *    https://github.com/oncletom/grunt-crx
 *
 */
module.exports = function(grunt) {

  grunt.config.set('crx', {
    build: {
      src: 'dist/**/*',
      dest: 'build/<%= pkg.name %>-<%= pkg.version %>-dev.crx',
      zipDest: 'build/<%= pkg.name %>-<%= pkg.version %>-dev.zip',
      options: {
        "privateKey": "key.pem"
      }
    }   
  }); 

  grunt.loadNpmTasks('grunt-crx');
};
