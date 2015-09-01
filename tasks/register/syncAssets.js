module.exports = function (grunt) {
	grunt.registerTask('syncAssets', [
		'jst:dev',
		'sass:dev',
    'jade:dev',
		'sync:dev',
		'coffee:dev'
	]);
};
