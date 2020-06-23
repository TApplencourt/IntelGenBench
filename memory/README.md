# Goal

Measure L3 Bandwith of your Gen*.

# Requirement
- `ruby2.5` 
- ryby gem (`gem install`):
  - `opencl_ruby_ffi`
  - `ascii_charts` 
- `ocloc` (see <https://github.com/intel/compute-runtime>)
 
# Kernel

Pseudo code used:
```
__attribute__((intel_reqd_sub_group_size(#{subgroup_size})))
__kernel void icule(global #{opencl_type} * restrict a, global #{opencl_type} * restrict b) {
    const int i = get_global_id(0);
<% UNROLL_FACTOR["copy"].times do  %>
  <% UNROLL_FACTOR["read"].times do  %>
    data <- a[i] 
  <% end %>
  <% UNROLL_FACTOR["write"].times do  %>
    data -> b[i];
  <% end %>
<% end %>
}
```
 
- The `subgroup_size` is fixed to 16.
- The `UNROLL_FACTOR` is fixed to 1000 per type.
    - We will run all the bencharmk for `copy`, `read` and `write`.
- We will `{int,float,double} * {1, 2 ,4}` opencl type.

# Summary

- No kernels drag more than 64B/clk/subslice.
- In maximun:
  - In GT2 (1 slice / 3 sublice), you can optain 95% of peak (60.95 B/clk/subslice). 
  - In GT3 (2 slice /3 sublice), you can optain 79% of peak (50.74 B/clk/subslice).

# Result

See `.log` files


### GT3 Posible Explanation.

Maybe L3 fabric contention?

# Todo:

- Try to use SIMD32.
   - `intel_reqd_sub_group_size(32)` does NOT generate SIMD32 instruction
- Use a runtime with introspection capabilities (`intel_get_thread_ID`, `intel_get_slice_ID`), to force  threads to be executed only on one Slice to verify our L3 fabric contention hypothesis.
- Run it on a GT4.
