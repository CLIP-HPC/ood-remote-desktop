// OnDemand's dynamic form directives (data-hide-*, data-min-*) are off on this site
// (bc_dynamic_js: false in ondemand.d), so the partition-dependent fields are handled
// here, as in the RStudio app's form.js.

// GPU type and count only apply to the g partition (submit.yml.erb ignores them
// otherwise). On a cluster without g, form.yml.erb leaves both fields out, and the
// jQuery selections below are empty. OnDemand 4 wraps each field in
// "#<field id>_wrapper" and hides with Bootstrap's d-none, the same way its own
// dynamic_forms.js toggleItemVisible() does
function applyGpuVisibility() {
  var isGpu = $('select[name$="[partition]"]').val() === 'g';
  ['gpu_type', 'gpu_count'].forEach(function (field) {
    var $input = $('[name$="[' + field + ']"]');
    $('#' + $input.attr('id') + '_wrapper').toggleClass('d-none', !isGpu);
  });
}

// The submit filter requires at least 128 GB on the m partition: raise the minimum
// there, and raise the current value if it is below it
var MIN_RAM = { m: 128 };

function applyRamMinimum() {
  var min = MIN_RAM[$('select[name$="[partition]"]').val()] || 1;
  var $ram = $('input[name$="[ram]"]');
  $ram.attr('min', min);
  if (Number($ram.val()) < min) {
    $ram.val(min).trigger('change');
  }
}

// Each GPU type option carries data-max-gpus: the most GPUs of that type on one node,
// capped by the QOS. Use it as the GPU count maximum, and lower the current value to it
function applyGpuMaximum() {
  var max = Number($('select[name$="[gpu_type]"] option:selected').data('max-gpus'));
  var $count = $('input[name$="[gpu_count]"]');
  if (!max || !$count.length) {
    return;
  }
  $count.attr('max', max);
  if (Number($count.val()) > max) {
    $count.val(max).trigger('change');
  }
}

$(document).on('change', 'select[name$="[partition]"]', function () {
  applyGpuVisibility();
  applyRamMinimum();
});

$(document).on('change', 'select[name$="[gpu_type]"]', applyGpuMaximum);

$(function () {
  applyGpuVisibility();
  applyRamMinimum();
  applyGpuMaximum();
});
