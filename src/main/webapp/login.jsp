<%@ page import="java.sql.*"%>
<%
    String userName = request.getParameter("userName");
    String password = request.getParameter("password");
    Class.forName("com.mysql.cj.jdbc.Driver");
    try (Connection con = DriverManager.getConnection(
             System.getenv("DB_URL"), System.getenv("DB_USER"), System.getenv("DB_PASSWORD"));
         PreparedStatement ps = con.prepareStatement(
             "select * from USER where username=? and password=?")) {
        ps.setString(1, userName);
        ps.setString(2, password);
        try (ResultSet rs = ps.executeQuery()) {
            if (rs.next()) {
                session.setAttribute("userName", userName);
                response.sendRedirect("success.jsp");
            } else {
                out.println("Invalid password <a href='index.jsp'>try again</a>");
            }
        }
    }
%>
