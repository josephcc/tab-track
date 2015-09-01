/**
 * Clean files and folders.
 *
 * ---------------------------------------------------------------
 *
 * This grunt task is configured to clean out the contents in the .tmp/public of your
 * sails project.
 *
 * For usage docs see:
 *    https://github.com/gruntjs/grunt-contrib-clean
 */
module.exports = function(grunt) {

  grunt.config.set('update_json', {
    options: {
      src: 'package.json',
      indent: "  "
    },
    bower: {
      dest: 'bower.json',
      fields: 'name version description repository homepage license keywords'
    },
    manifest: {
      dest: 'dist/manifest.json',
      fields: {
        'name': null,
        'version': null,
        'description': null,
        'homepage_url': 'homepage',
        'author': null,
      }
    }
  }); 

  grunt.loadNpmTasks('grunt-update-json');
};
