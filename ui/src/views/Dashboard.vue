<template>
  <div>
    <h1>{{$t('dashboard.title')}}</h1>

    <!-- error message -->
    <div v-if="errorMessage" class="alert alert-danger alert-dismissable">
      <span class="pficon pficon-error-circle-o"></span>
      {{ errorMessage }}.
    </div>

    <!-- DNS blacklist enabled warning -->
    <div v-if="ftlEnabled" class="alert alert-warning alert-dismissable">
      <span class="pficon pficon-warning-triangle-o"></span>
      <strong>{{$t('warning')}}: </strong>
      <span>{{$t('dashboard.dns_blacklist_enabled')}}.
        <a href="/nethserver#/applications/nethserver-blacklist" target="_blank">
          {{$t('dashboard.configure_threat_shield')}}
        </a>
      </span>
    </div>

    <div v-if="!uiLoaded" class="spinner spinner-lg"></div>
    <div v-if="uiLoaded">
      <form class="form-horizontal" v-on:submit.prevent="btSaveClick">
        <div class="form-group">
          <label
            class="col-sm-2 control-label margin-top-2"
          >{{$t('dashboard.flashstart_enabled')}}</label>
          <div class="col-sm-2 margin-top-6">
            <span v-if="flashstartEnabled">
              <span class="pficon pficon-ok login-icon"></span>
            </span>
            <span v-else>
              <span class="pficon pficon-error-circle-o login-icon"></span>
            </span>
          </div>
        </div>
        <div class="form-group" v-if="flashstartEnabled">
          <label
            class="col-sm-2 control-label margin-top-2"
          >{{$t('dashboard.authentication_status')}}</label>
          <div class="col-sm-2 margin-top-6">
            <span v-if="loginOk">
              <span class="pficon pficon-ok login-icon"></span>
            </span>
            <span v-else>
              <span class="pficon pficon-error-circle-o login-icon"></span>
            </span>
          </div>
        </div>
        <div class="form-group" v-if="flashstartEnabled">
          <label class="col-sm-2 control-label margin-top-2">{{$t('dashboard.cloud_portal')}}</label>
          <div class="col-sm-2 margin-top-6">
            <a target="_blank" v-bind:href="portalUrl">{{$t('dashboard.access')}}</a>
          </div>
        </div>
      </form>
    </div>
  </div>
</template>

<script>
export default {
  name: "Dashboard",
  components: {
  },
  props: {
  },
  mounted() {
    this.getConfig()
    this.getFtlEnabled();
  },
  data() {
    return {
      uiLoaded: true,
      errorMessage: null,
      loginOk: false,
      flashstartEnabled: false,
      ftlEnabled: false,
    };
  },
  methods: {
    getConfig() {
      this.errorMessage = null
      this.uiLoaded = false;
      var ctx = this;
      nethserver.exec(
        ["nethserver-flashstart/read"],
        { "config": "dashboard" },
        null,
        function(success) {
          var output = JSON.parse(success)
          ctx.loginOk = output.configuration.loginOk
          ctx.flashstartEnabled = output.configuration.flashstartEnabled === 'enabled'
          ctx.portalUrl = output.configuration.portalUrl
          ctx.uiLoaded = true
        },
        function(error) {
          ctx.showErrorMessage(ctx.$i18n.t("dashboard.error_retrieving_dashboard_data"), error)
        }
      );
    },
    showErrorMessage(errorMessage, error) {
      console.error(errorMessage, error) /* eslint-disable-line no-console */
      this.errorMessage = errorMessage
    },
    getFtlEnabled() {
      // Check if DNS blacklist is enabled
      var ctx = this;
      nethserver.exec(
        ["nethserver-flashstart/read"],
        { "config": "ftl" },
        null,
        function(success) {
          var output = JSON.parse(success);

          if (output.configuration.props) {
            const status = output.configuration.props.status === 'enabled';
            const roles = output.configuration.props.Roles;
            ctx.ftlEnabled = status && roles;
          } else {
            // DNS blacklist not installed
            ctx.ftlEnabled = false;
          }
        },
        function(error) {
          console.error(error);
        }
      );
    }
  }
}
</script>

<style>
.margin-top-6 {
  margin-top: 6px;
}

.margin-top-2 {
  margin-top: 2px;
}

.login-icon {
  margin-left: 5px;
  font-size: 140%;
}
</style>