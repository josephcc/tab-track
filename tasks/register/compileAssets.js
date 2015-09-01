module.exports = function (grunt) {
	grunt.registerTask('compileAssets', [
		'clean:dev',
		'jst:dev',
    'jade:dev',
		'sass:dev',
		'copy:dev',
		'coffee:dev',
    'update_json:bower',
    'update_json:manifest'
	]);
};
