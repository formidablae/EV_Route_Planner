<template>
  <div id="app">
    <Planner/>
  </div>
</template>

<script>
import Planner from './views/Planner.vue'

export default {
  name: 'app',
  components: {
    Planner
  }
}
</script>

<style>
#app {
  font-family: 'Avenir', Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
}
  body {
    margin: 0;
  }
</style>
