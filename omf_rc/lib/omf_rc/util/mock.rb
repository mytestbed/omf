module OmfRc::Util::Mock
  def test(comm, node, host, context_id)
      OmfRc::Cmd.exec("ls") do |output, status|
        if status.exitstatus == 0
          inform = OmfCommon::Message.inform(context_id, 'TEST') do |m|
            m.element('test', output)
          end.sign
          comm.publish(node, inform, host)
        end
      end
    end
  end
end
