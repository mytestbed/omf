#
# Library of client side helpers
#
require 'fcntl'
require 'omf-common/mobject'

#
# Run an application on the client.
#
# Borrows from Open3
#
class ExecApp < MObject

  # Holds the pids for all active apps
  @@apps = Hash.new

  def ExecApp.[](id)
    app = @@apps[id]
    if (app == nil)
      info "Unknown application '#{id}/#{id.class}'"
    end
    return app
  end

  def ExecApp.killAll(signal = 'KILL')
    @@apps.each_value { |app|
      app.kill(signal)
    }
  end

  def stdin(line)
    debug "writing '#{line}' to app '#{@id}'"
    @stdin.write("#{line}\n")
    @stdin.flush
  end

  def kill(id, signal = 'KILL')
    Process.kill(signal, @pid)
  end

  #
  # Run an application 'cmd' in a separate thread and monitor
  # its stdout. Also send status reports to the 'observer' by
  # calling its "onAppEvent(eventType, appId, message")"
  #
  # @param id ID of application (used for reporting)
  # @param observer Observer of application's progress
  # @param cmd Command path and args
  # @param mapStderrToStdout If true report stderr as stdin [false]
  #
  def initialize(id, observer, cmd, mapStderrToStdout = false)

    @id = id
    @observer = observer
    @@apps[id] = self

    pw = IO::pipe   # pipe[0] for read, pipe[1] for write
    pr = IO::pipe
    pe = IO::pipe

    debug "Starting application '#{id}': #{cmd}"
    @observer.onAppEvent('STARTED', @id)
    @pid = fork {
      # child will remap pipes to std and exec cmd
      pw[1].close
      STDIN.reopen(pw[0])
      pw[0].close

      pr[0].close
      STDOUT.reopen(pr[1])
      pr[1].close

      pe[0].close
      STDERR.reopen(pe[1])
      pe[1].close

      begin
        exec(cmd)
      rescue => ex
        if cmd.kind_of?(Array)
          cmd = cmd.join(' ')
        end
        STDERR.puts "exec failed for '#{cmd}'(#{$!}): #{ex}"
      end
      # Should never get here
      exit!
    }

    pw[0].close
    pr[1].close
    pe[1].close
    monitorAppPipe('stdout', pr[0])
    monitorAppPipe(mapStderrToStdout ? 'stdout' : 'stderr', pe[0])
    # Create thread which waits for application to exit
    Thread.new(id, @pid) {|id, pid|
      ret = Process.waitpid(pid)
      status = $?
      @@apps.delete(@id)
      # app finished
      if status == 0
        s = "OK"
        info "Application '#{id}' finished"
      else
        s = "ERROR"
        error "Application '#{id}' failed (code=#{status})"
      end
      @observer.onAppEvent("DONE.#{s}", @id, "status: #{status}")
    }
    @stdin = pw[1]
  end

  private

  #
  # Create a thread to monitor the process and its output
  # and report that back to the server
  #
  # @parma name Name of app stream to monitor (should be stdout, stderr)
  # @param pipe Pipe to read from
  #
  def monitorAppPipe(name, pipe)
    Thread.new() {
      begin
        while true do
          s = pipe.readline.chomp
          @observer.onAppEvent(name, @id, s)
        end
      rescue EOFError
        # do nothing
      rescue Exception => err
        error "monitorApp(#{@id}): #{err}"
      ensure
#        debug "#{@id} IO close"
        pipe.close
      end
    }
  end
end

if $0 == __FILE__
  MObject.initLog('test')

  class TestMock
    def onAppEvent (name, id, msg = nil)
      puts "onAppEvent: name=>'#{name}' id=>'#{id}' msg=>'#{msg}'"
    end
  end
#  w = ExecApp.new(:testApp, TestMock.new, "ping -c 3 external1")
  w = ExecApp.new(:commServer, TestMock.new, '../c/commServer/commServer -d 8 -l - --iface eth1')

#  w = ExecApp.new(:testApp, "foo -c")
  gets
  puts "Threads: #{Thread.list.join(', ')}"
end
